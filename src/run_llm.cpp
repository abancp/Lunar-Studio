#include <llama.h>
#include <iostream>
#include <vector>
#include <cmath>
#include <cstring>
#include "embed.hpp"
#include "run_llm.hpp"
#include <functional>

static int N_CTX = 2048;
static int N_BATCH = 512;
static int MAX_TOKENS_OUT = 400;

static float TEMP = 1.0f;
static int TOP_K = 64;
static float TOP_P = 0.95;
static float MIN_KEEP_P = 0;

std::string run_model(std::string prompt, const char *model_path, bool allowSearch, std::vector<std::string> search_results, TokenCallback token_callback)
{
    llama_backend_init();

    // Load model
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;

    llama_model *model = llama_load_model_from_file(model_path, model_params);
    if (!model)
    {
        std::cerr << "Error: Failed to load model from " << model_path << std::endl;
        llama_backend_free();
        exit(1);
    }

    // std::cout << "Model loaded successfully" << std::endl;

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;

    llama_context *ctx = llama_new_context_with_model(model, ctx_params);
    if (!ctx)
    {
        std::cerr << "Error: Failed to create context" << std::endl;
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    // std::cout << "Context created successfully" << std::endl;

    const llama_vocab *vocab = llama_model_get_vocab(model);

    // Apply chat template if the model has one (CRITICAL for chat models like Gemma)
    std::string formatted_prompt;
    const char *template_str = llama_model_chat_template(model, nullptr); // nullptr = default template

    if (template_str != nullptr && strlen(template_str) > 0)
    {
        // Define system prompt
        // const char *system_prompt = "SYSTEM : You are a helpful AI assistant. Use information from given data if you need for better answer . given data : In 1614, John Napier introduced logarithms, dramatically simplifying complex calculations and inspiring early analog computing devices. In the 1820s, Charles Babbage designed the Difference Engine to automate polynomial computations and later conceptualized the Analytical Engine—a general-purpose mechanical computer featuring memory and programmable control via punched cards. Ada Lovelace, who wrote the first algorithm for this machine, is recognized as the world’s first computer programmer";
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

        // Create messages array with system prompt + user message
        std::vector<llama_chat_message> messages = {
            {"system", system_prompt},
            {"user", allowSearch ? prompt.c_str() : final_user_message.c_str()}};

        char *formatted = new char[8192]; // Buffer for formatted prompt
        int32_t result = llama_chat_apply_template(
            template_str, // template string (NOT model)
            messages.data(),
            messages.size(),
            true, // add_assistant_prefix - this prepares for model response
            formatted,
            8192);

        if (result > 0)
        {
            formatted_prompt = std::string(formatted, result);
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

    if (allowSearch)
    {
        formatted_prompt += "<think>oh </think>";
    }
    std::cout << "Using chat template with system prompt. Formatted prompt:\n[" << formatted_prompt << "]" << std::endl;
    std::cout << "Length: " << formatted_prompt.length() << " chars" << std::endl;

    int32_t n_tokens_needed = llama_tokenize(vocab, formatted_prompt.c_str(), formatted_prompt.length(), nullptr, 0, true, true);

    if (n_tokens_needed < 0)
        n_tokens_needed = -n_tokens_needed;

    std::vector<llama_token> tokens(n_tokens_needed);

    int32_t n_input = llama_tokenize(vocab, formatted_prompt.c_str(), formatted_prompt.length(), tokens.data(), tokens.size(), true, true);

    if (n_input < 0)
    {
        std::cerr << "Error: Tokenization failed" << std::endl;
        llama_free(ctx);
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    // std::cout << "Tokenized " << n_input << " tokens" << std::endl;

    // Debug: Print first few tokens
    // std::cout << "First tokens: ";
    // for (int i = 0; i < std::min(10, n_input); i++)
    // {
    //     std::cout << tokens[i] << " ";
    // }
    // std::cout << std::endl;

    llama_batch batch = llama_batch_init(N_BATCH, 0, 1);
    int pos = 0;
    for (int i = 0; i < n_input; i++)
    {
        batch.token[i] = tokens[i];
        batch.pos[i] = pos;
        batch.seq_id[i][0] = 0;
        batch.n_seq_id[i] = 1;
        batch.logits[i] = false;
        pos++;
    }

    batch.n_tokens = n_input;

    if (n_input > 0)
    {
        batch.logits[n_input - 1] = true;
    }

    // std::cout << "Batch created successfully" << std::endl;

    // Compute the embedding
    if (llama_decode(ctx, batch) != 0)
    {
        std::cerr << "Error: llama_decode() failed" << std::endl;
        llama_batch_free(batch);
        llama_free(ctx);
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    batch.n_tokens = 0;
    // std::cout << "Encoding successful" << std::endl;

    // Create sampler chain - ORDER MATTERS!
    llama_sampler_chain_params chain_params = llama_sampler_chain_default_params();
    llama_sampler *sampler = llama_sampler_chain_init(chain_params);

    // Add samplers in the correct order to prevent repetition
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(TOP_K));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(TOP_P, MIN_KEEP_P));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(TEMP));

    // Add repetition penalty to prevent loops
    llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
                                         64,   // penalty_last_n: look back 64 tokens
                                         1.1f, // penalty_repeat: penalize repeated tokens (1.0 = no penalty)
                                         0.0f, // penalty_freq: frequency penalty
                                         0.0f  // penalty_present: presence penalty
                                         ));

    // CRITICAL: Add the distribution sampler at the end
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(0)); // 0 = seed (use random)

    std::string output;
    output.reserve(4096);

    pos = n_input;

    llama_batch gen_batch = llama_batch_init(1, 0, 1);

    for (int t = 0; t < MAX_TOKENS_OUT; t++)
    {
        llama_token token = llama_sampler_sample(sampler, ctx, -1);
        if (token == llama_token_eos(vocab))
        {
            break;
        }

        char piece_buf[128];
        int32_t n_piece = llama_token_to_piece(vocab, token, piece_buf, sizeof(piece_buf), 0, true);
        if (n_piece > 0)
        {
            output.append(piece_buf, n_piece);
            std::string p(piece_buf, n_piece);
            if (token_callback)
            {
                token_callback(p);
            }
            else
            {
                std::cout << p << std::flush;
            }
        }
        gen_batch.token[0] = token;
        gen_batch.pos[0] = pos;
        gen_batch.seq_id[0][0] = 0;
        gen_batch.n_seq_id[0] = 1;
        gen_batch.logits[0] = true;
        gen_batch.n_tokens = 1;

        if (llama_decode(ctx, gen_batch) != 0)
        {
            std::cerr << "Decode failed \n";
            break;
        }

        gen_batch.n_tokens = 1;
        pos++;
    }

    // Cleanup
    llama_sampler_free(sampler);
    llama_batch_free(gen_batch);
    llama_batch_free(batch);
    llama_free(ctx);
    llama_free_model(model);
    llama_backend_free();
    return output;
}