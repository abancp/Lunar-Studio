#include <llama.h>
#include <iostream>
#include <vector>
#include <cmath>
#include <cstring>
#include "embed.hpp"
#include "run_llm.hpp"
#include <functional>
#include <ctime>
#include <chrono>

static int N_CTX = 2048;
static int N_BATCH = 512;
static int MAX_TOKENS_OUT = 400;

static float TEMP = 1.0f;
static int TOP_K = 64;
static float TOP_P = 0.95;
static float MIN_KEEP_P = 0;

llama_model_params model_params;
llama_model *model = nullptr;
llama_context_params ctx_params;
llama_context *ctx;
const llama_vocab *vocab = nullptr;
const char *template_str;

void load_model(const char *model_path)
{
    llama_backend_init();
    model_params = llama_model_default_params();
    model_params.n_gpu_layers = 999;
    model_params.use_mmap = true;
    model_params.use_mlock = false;

    model = llama_load_model_from_file(model_path, model_params);
    if (!model)
    {
        std::cerr << "Error: Failed to load model from " << model_path << std::endl;
        llama_backend_free();
        exit(1);
    }

    std::cout << "Model loaded successfully" << std::endl;

    ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_threads = 4; // Use available CPU cores
    ctx_params.n_threads_batch = 4;
    ctx_params.n_batch = 512;

    ctx = llama_new_context_with_model(model, ctx_params);
    if (!ctx)
    {
        std::cerr << "Error: Failed to create context" << std::endl;
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    std::cout << "Context created successfully" << std::endl;

    vocab = llama_model_get_vocab(model);
    std::cout << "Vocab get" << std::endl;

    template_str = llama_model_chat_template(model, nullptr); // nullptr = default template
    std::cout << "Template loaded" << std::endl;
}
std::string run_model(std::string prompt, const char *model_path, bool allowSearch, std::vector<std::string> search_results, TokenCallback token_callback)
{
    std::string formatted_prompt;

    if (template_str != nullptr && strlen(template_str) > 0)
    {
        const char *system_prompt = allowSearch ? R"SYS(
You are LunarStudio, created by Aban Muhammed (AI Researcher & Engineer).

You can use one tool:
search("query")

CRITICAL RULE:
Before deciding to search, you MUST classify the user message into one of two types:

TYPE A — CASUAL / SOCIAL (NO SEARCH):
Includes:
- "hi", "hello", "hey", "yo"
- "good morning", "good night"
- "how are you"
- "what's up"
- "thank you", "ok", "bye"
- any short greeting or social talk 
For TYPE A: Reply normally with a friendly message. DO NOT use search().

TYPE B — INFORMATION REQUEST (SEARCH):
Includes:
- definitions, explanations, facts
- "what is...", "explain...", "difference between..."
- technical, academic, topic-based questions
- any message requesting knowledge or information
For TYPE B: Output ONLY search("clean topic").

SEARCH QUERY RULES:
- short, noun-based, topic only
- no question words
Examples:
"What is RAM?" -> search("ram memory")
"Why stack vs queue?" -> search("stack queue difference")
"Explain transformers" -> search("transformer neural networks")

DO NOT search unless the message is clearly TYPE B.
If the message is TYPE A, NEVER search.
If unsure, treat the message as TYPE A.
- Dont think for this . this is a simple task

)SYS"
                                                : R"SYS(
You are LunarStudio. You now have:
1) The user's original QUESTION.
2) SEARCH_RESULT containing multiple retrieved paragraphs from documents.

Your job:
- Answer the QUESTION using ONLY information found inside SEARCH_RESULT.
- Ignore unrelated or extra content.
- Do NOT call search().
- Do NOT guess anything not in SEARCH_RESULT.
- Summarize the relevant parts into a clear, human-friendly answer.
- Keep it accurate, concise, and well-structured.
)SYS";

        std::string combined_search_results = allowSearch ? "" : "1 : " + search_results[0] + "\n2 : " + search_results[1] + "\n3 : " + search_results[2] + "\n";
        std::string final_user_message = std::string("QUESTION:\n") + prompt + "\n\nSEARCH_RESULT:\n" + combined_search_results;
        std::cout << final_user_message << std::endl;

        std::vector<llama_chat_message> messages = {
            {"system", system_prompt},
            {"user", allowSearch ? prompt.c_str() : final_user_message.c_str()}};

        // Apply chat template into a fixed-size buffer
        const int FORMATTED_BUF_SIZE = 8192;
        char *formatted = new char[FORMATTED_BUF_SIZE];
        int32_t result = llama_chat_apply_template(
            template_str,
            messages.data(),
            messages.size(),
            true,
            formatted,
            FORMATTED_BUF_SIZE);

        if (result > 0)
        {
            formatted_prompt.assign(formatted, result);
        }
        else
        {
            formatted_prompt = prompt;
            std::cout << "Chat template application failed, using raw prompt" << std::endl;
        }
        delete[] formatted;
    }
    else
    {
        formatted_prompt = prompt;
        std::cout << "No chat template found, using raw prompt" << std::endl;
    }

    std::cout << "Using chat template with system prompt. Formatted prompt:\n[" << formatted_prompt << "]" << std::endl;
    std::cout << "Length: " << formatted_prompt.length() << " chars" << std::endl;

    if (!vocab || !model || !ctx)
    {
        std::cerr << "[C++] run_model: fatal - model/vocab/ctx not initialized\n";
        return std::string();
    }

    // --- Tokenize (single call to get needed size) ---
    int32_t n_tokens_needed = llama_tokenize(vocab, formatted_prompt.c_str(), (int)formatted_prompt.length(), nullptr, 0, true, true);
    std::cout << "Tokenize: needed = " << n_tokens_needed << std::endl;
    if (n_tokens_needed < 0)
        n_tokens_needed = -n_tokens_needed;
    if (n_tokens_needed <= 0)
    {
        std::cerr << "Error: tokenizer returned zero tokens" << std::endl;
        return std::string();
    }

    // Reserve vector once to avoid multiple allocations
    std::vector<llama_token> tokens;
    tokens.resize((size_t)n_tokens_needed);

    int32_t n_input = llama_tokenize(vocab, formatted_prompt.c_str(), (int)formatted_prompt.length(), tokens.data(), (int)tokens.size(), true, true);
    std::cout << "Tokenization completed, n_input = " << n_input << std::endl;
    if (n_input <= 0)
    {
        std::cerr << "Error: Tokenization failed" << std::endl;
        return std::string();
    }

    // --- Optimized input feeding ---
    // Use a single batch struct and fill it per chunk. Keep N_BATCH large if memory allows.
    // Just use this instead of your entire while loop:
    llama_batch batch = llama_batch_get_one(tokens.data(), n_input);

    if (llama_decode(ctx, batch) != 0)
    {
        std::cerr << "Error: llama_decode failed" << std::endl;
        return "";
    }

    // That's it! No loops, no manual filling!
    std::cout << "[C++] Input feeding complete (" << n_input << " tokens)." << std::endl;

    // --- Sampler chain setup (keeps same behavior) ---
    llama_sampler_chain_params chain_params = llama_sampler_chain_default_params();
    llama_sampler *sampler = llama_sampler_chain_init(chain_params);

    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(TOP_K));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(TOP_P, MIN_KEEP_P));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(TEMP));
    llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
                                         64,
                                         1.1f,
                                         0.0f,
                                         0.0f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(0));

    std::cout << "Sampler completed" << std::endl;

    // --- Generation loop (reuse gen_batch) ---
    std::string output;
    output.reserve(4096);

    int pos = n_input;
    llama_batch gen_batch = llama_batch_init(1, 0, 1);
    std::cout << "Batch initialization completed" << std::endl;

    // ---- Performance timers ----
    using clock_t = std::chrono::steady_clock;
    auto gen_start = clock_t::now();
    auto token_start = clock_t::now();

    int generated_tokens = 0;
    double total_gen_ms = 0.0;

    for (int t = 0; t < MAX_TOKENS_OUT; ++t)
    {
        auto step_start = clock_t::now();

        llama_token token = llama_sampler_sample(sampler, ctx, -1);
        if (token == llama_token_eos(vocab))
        {
            std::cout << "[C++] EOS reached at step " << t << std::endl;
            break;
        }

        // convert token → string
        char piece_buf[128];
        const int32_t n_piece =
            llama_token_to_piece(vocab, token, piece_buf, sizeof(piece_buf), 0, true);

        if (n_piece > 0)
        {
            if (token_callback)
                token_callback(std::string(piece_buf, n_piece));

            output.append(piece_buf, n_piece);
        }

        // decode for next token
        gen_batch.token[0] = token;
        gen_batch.pos[0] = pos++;
        gen_batch.seq_id[0][0] = 0;
        gen_batch.n_seq_id[0] = 1;
        gen_batch.logits[0] = true;
        gen_batch.n_tokens = 1;

        if (llama_decode(ctx, gen_batch) != 0)
        {
            std::cerr << "[C++] Error: llama_decode failed during generation at step "
                      << t << std::endl;
            break;
        }

        // ---- Performance stats ----
        auto step_end = clock_t::now();
        double step_ms = std::chrono::duration<double, std::milli>(step_end - step_start).count();

        generated_tokens++;
        total_gen_ms += step_ms;

        double tps_instant = 1000.0 / step_ms;
        double tps_avg = (generated_tokens * 1000.0) / total_gen_ms;
    }

    auto gen_end = clock_t::now();
    double gen_total_ms =
        std::chrono::duration<double, std::milli>(gen_end - gen_start).count();

    if (generated_tokens > 0)
    {
        double final_tps = (generated_tokens * 1000.0) / gen_total_ms;

        std::cout << "\n========== Generation Summary ==========\n";
        std::cout << "Generated tokens : " << generated_tokens << "\n";
        std::cout << "Total time       : " << gen_total_ms << " ms\n";
        std::cout << "Final Avg t/s    : " << final_tps << "\n";
        std::cout << "=======================================\n\n";
    }

    // cleanup -- keep model & ctx alive for subsequent calls
    // llama_sampler_free(sampler);
    // llama_batch_free(gen_batch);

    return output;
}

