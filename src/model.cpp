#include "model.hpp"
#include "llama.h"
#include <iostream>
#include <vector>
#include <string>
#include <cstring>

static llama_model *g_model = nullptr;
static llama_sampler *g_sampler = nullptr;
static const llama_vocab *g_vocab = nullptr;
static llama_model_params g_model_params;
static llama_context_params g_ctx_params;

static std::vector<llama_chat_message> g_messages;

void remove_think_blocks(std::string &s)
{
    const std::string start_tag = "<think>";
    const std::string end_tag = "</think>";

    while (true)
    {
        // find start
        size_t s_pos = s.find(start_tag);
        if (s_pos == std::string::npos)
            break; // no more <think>

        // find end
        size_t e_pos = s.find(end_tag, s_pos);
        if (e_pos == std::string::npos)
        {
            // malformed: remove everything from <think> to end
            s.erase(s_pos);
            break;
        }

        // remove <think> ... </think>
        s.erase(s_pos, (e_pos + end_tag.length()) - s_pos);
    }

    // optional: trim leading whitespace/newlines after removal
    while (!s.empty() && (s[0] == '\n' || s[0] == ' '))
        s.erase(s.begin());
}

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
    g_ctx_params.n_ctx = 2048;
    g_ctx_params.n_batch = 2048;

    g_sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(g_sampler, llama_sampler_init_min_p(0.05f, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

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
                      const char *,
                      bool,
                      std::vector<std::string>,
                      TokenCallback cb)
{
    std::cout << "Model running......... " << "\n";

    g_messages.push_back({"user", strdup(prompt.c_str())});

    std::string final_prompt = build_prompt_from_history();
    std::cout << "Final : " << final_prompt << "\n";

    llama_context *ctx = llama_init_from_model(g_model, g_ctx_params);
    if (!ctx)
        return "";

    std::cout << "New context " << "\n";

    bool is_first = true;

    int n = -llama_tokenize(g_vocab, final_prompt.c_str(), final_prompt.size(),
                            nullptr, 0, is_first, true);
    if (n < 0)
        return "";

    std::vector<llama_token> toks(n);
    llama_tokenize(g_vocab, final_prompt.c_str(), final_prompt.size(),
                   toks.data(), toks.size(), is_first, true);

    llama_batch batch = llama_batch_get_one(toks.data(), toks.size());

    std::string response;
    std::cout << "Tokenization Completed" << std::endl;
    while (true)
    {
        if (llama_decode(ctx, batch) != 0)
            break;

        llama_token tok = llama_sampler_sample(g_sampler, ctx, -1);

        char buf[256];
        int n = llama_token_to_piece(g_vocab, tok, buf, sizeof(buf), 0, true);
        if (n < 0)
        {

            std::cout << "Exited due to invalid token" << std::endl;
            break;
        }

        std::string piece(buf, n);
        response += piece;

        if (llama_vocab_is_eog(g_vocab, tok))
        {
            std::cout << "EOG hit : " << tok << std::endl;
            break;
        }

        if (cb)
            cb(piece); // stream to Python
        batch = llama_batch_get_one(&tok, 1);
    }

    llama_free(ctx);
    remove_think_blocks(response);
    g_messages.push_back({"assistant", strdup(response.c_str())});

    return response;
}
