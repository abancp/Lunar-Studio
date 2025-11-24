#include "model.hpp"
#include "llama.h"
#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <thread>
#include "utils/remove_think_blocks.hpp"

static llama_model *g_model = nullptr;
static llama_sampler *g_sampler = nullptr;
static const llama_vocab *g_vocab = nullptr;
static llama_model_params g_model_params;
static llama_context_params g_ctx_params;
static llama_context *g_ctx;
static std::vector<llama_chat_message> g_messages;

// Track how many tokens are already in KV cache
static int g_cached_tokens = 0;
// Track prompt tokens separately to detect mismatches
static std::vector<llama_token> g_cached_prompt_tokens;

int load_model(const char *model_path)
{
    llama_log_set(
        [](ggml_log_level level, const char *text, void *)
        {
            if (level >= GGML_LOG_LEVEL_ERROR)
                fprintf(stderr, "%s", text);
        },
        nullptr);

    ggml_backend_load_all();

    g_model_params = llama_model_default_params();
    g_model_params.n_gpu_layers = 99;

    g_model = llama_model_load_from_file(model_path, g_model_params);
    if (!g_model)
        return 1;

    g_vocab = llama_model_get_vocab(g_model);

    g_ctx_params = llama_context_default_params();
    g_ctx_params.n_ctx = 2048 * 4;
    g_ctx_params.n_batch = 2048;
    g_ctx_params.n_threads = std::thread::hardware_concurrency();
    g_ctx_params.n_threads_batch = std::thread::hardware_concurrency();

    g_ctx = llama_init_from_model(g_model, g_ctx_params);

    g_sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(g_sampler, llama_sampler_init_min_p(0.05f, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    g_cached_tokens = 0;
    g_cached_prompt_tokens.clear();

    std::cout << "[DEBUG] Model loaded successfully\n";

    return 0;
}

static std::string build_prompt_from_history()
{
    const char *tmpl = llama_model_chat_template(g_model, nullptr);

    if (!tmpl)
        throw std::runtime_error("Chat template missing");

    std::vector<char> out(4096);

    int n = llama_chat_apply_template(
        tmpl,
        g_messages.data(),
        g_messages.size(),
        true,
        out.data(),
        out.size());

    if (n > (int)out.size())
    {
        out.resize(n);
        n = llama_chat_apply_template(
            tmpl, g_messages.data(), g_messages.size(),
            true,
            out.data(), out.size());
    }

    if (n < 0)
        throw std::runtime_error("Failed applying chat template");

    return std::string(out.data(), n);
}

std::string run_model(std::string prompt,
                      bool,
                      std::vector<std::string>,
                      TokenCallback cb)
{
    std::cout << "[DEBUG] ========== NEW TURN ==========\n";
    std::cout << "[DEBUG] User prompt: " << prompt.substr(0, 100) << "...\n";

    g_messages.push_back({"user", strdup(prompt.c_str())});
    std::cout << "[DEBUG] Total messages in history: " << g_messages.size() << "\n";

    std::string final_prompt = build_prompt_from_history();
    std::cout << "[DEBUG] Final prompt length: " << final_prompt.size() << " chars\n";

    if (!g_ctx)
    {
        std::cerr << "[ERROR] Context is null!\n";
        return "";
    }

    // Tokenize the FULL prompt
    bool is_first = true;
    int n = -llama_tokenize(g_vocab, final_prompt.c_str(), final_prompt.size(),
                            nullptr, 0, is_first, true);
    if (n < 0)
    {
        std::cerr << "[ERROR] Tokenization failed\n";
        return "";
    }

    std::vector<llama_token> toks(n);
    llama_tokenize(g_vocab, final_prompt.c_str(), final_prompt.size(),
                   toks.data(), toks.size(), is_first, true);

    std::cout << "[DEBUG] Total tokens: " << toks.size() 
              << ", Cached: " << g_cached_tokens << "\n";

    // CRITICAL FIX: Check if prompt tokens match cached tokens
    bool cache_valid = (g_cached_tokens > 0 && 
                        g_cached_tokens <= (int)toks.size());
    
    if (cache_valid)
    {
        // Verify the cached portion matches
        for (int i = 0; i < g_cached_tokens && i < (int)g_cached_prompt_tokens.size(); i++)
        {
            if (toks[i] != g_cached_prompt_tokens[i])
            {
                std::cout << "[WARNING] Token mismatch at position " << i 
                          << ". Cache invalid (think blocks were removed).\n";
                cache_valid = false;
                break;
            }
        }
    }
    else if (g_cached_tokens > (int)toks.size())
    {
        std::cout << "[WARNING] Cache tokens (" << g_cached_tokens 
                  << ") > actual tokens (" << toks.size() 
                  << "). Think blocks were removed.\n";
        cache_valid = false;
    }

    if (!cache_valid && g_cached_tokens > 0)
    {
        std::cout << "[DEBUG] Recreating context and reprocessing all tokens...\n";
        llama_free(g_ctx);
        g_ctx = llama_init_from_model(g_model, g_ctx_params);
        g_cached_tokens = 0;
        g_cached_prompt_tokens.clear();
    }

    // OPTIMIZATION: Only process NEW tokens (skip already cached ones)
    int tokens_to_process = toks.size() - g_cached_tokens;
    
    std::cout << "[DEBUG] Tokens to process: " << tokens_to_process << "\n";

    if (tokens_to_process > 0)
    {
        std::cout << "[DEBUG] Processing " << tokens_to_process << " new tokens...\n";
        
        // Create batch with only the new tokens
        llama_batch batch = llama_batch_get_one(
            toks.data() + g_cached_tokens, 
            tokens_to_process
        );

        std::cout << "[DEBUG] Decoding batch...\n";
        // Decode the new tokens into KV cache
        if (llama_decode(g_ctx, batch) != 0)
        {
            std::cerr << "[ERROR] Failed to decode batch\n";
            return "";
        }

        // Update cached token count
        g_cached_tokens = toks.size();
        g_cached_prompt_tokens = toks; // Store for validation next turn
        std::cout << "[DEBUG] Cache updated. New cached_tokens: " << g_cached_tokens << "\n";
    }
    else
    {
        std::cout << "[DEBUG] All tokens already cached, skipping prefill\n";
    }

    std::string response;
    std::string raw_response; // Store WITH think blocks
    int generated_tokens = 0;
    std::cout << "[DEBUG] Starting generation...\n";

    // Generation loop
    while (true)
    {
        // Sample next token
        llama_token tok = llama_sampler_sample(g_sampler, g_ctx, -1);

        char buf[256];
        int n = llama_token_to_piece(g_vocab, tok, buf, sizeof(buf), 0, true);
        if (n < 0)
        {
            std::cout << "[DEBUG] Invalid token encountered\n";
            break;
        }

        std::string piece(buf, n);
        raw_response += piece; // Keep original WITH think blocks
        generated_tokens++;

        if (llama_vocab_is_eog(g_vocab, tok))
        {
            std::cout << "[DEBUG] EOG hit: " << tok << " after " << generated_tokens << " tokens\n";
            break;
        }

        if (cb)
            cb(piece);

        // Decode the sampled token
        llama_batch batch = llama_batch_get_one(&tok, 1);
        if (llama_decode(g_ctx, batch) != 0)
        {
            std::cerr << "[ERROR] Failed to decode generated token\n";
            break;
        }

        g_cached_tokens++;
    }

    std::cout << "[DEBUG] Generated " << generated_tokens << " tokens\n";
    std::cout << "[DEBUG] Total cached tokens after generation: " << g_cached_tokens << "\n";
    std::cout << "[DEBUG] Raw response length (with <think>): " << raw_response.size() << " chars\n";

    // Store raw response for history (WITH think blocks for accurate cache)
    // g_last_raw_response = raw_response;
    
    // For display, remove think blocks
    response = raw_response;
    remove_think_blocks(response);
    std::cout << "[DEBUG] Cleaned response length (without <think>): " << response.size() << " chars\n";

    // CRITICAL: Store the RAW response in message history (with think blocks)
    // so that the next turn's prompt matches what's in the KV cache
    g_messages.push_back({"assistant", strdup(raw_response.c_str())});
    
    std::cout << "[DEBUG] ========== TURN END ==========\n\n";

    return response; // Return cleaned version to user
}