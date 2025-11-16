#include <llama.h>
#include <iostream>
#include <vector>
#include <cmath>
#include "embed.hpp"

std::vector<float> embed(std::string text, const char *model_path)
{
    // Initialize backend
    llama_backend_init();

    // Load model
    llama_model_params model_params = llama_model_default_params();
    llama_model *model = llama_load_model_from_file(model_path, model_params);
    if (!model)
    {
        std::cerr << "Error: Failed to load model from " << model_path << std::endl;
        llama_backend_free();
        exit(1);
    }


    // Setup context
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.embeddings = true;
    ctx_params.n_ctx = 512;

    llama_context *ctx = llama_new_context_with_model(model, ctx_params);
    if (!ctx)
    {
        std::cerr << "Error: Failed to create context" << std::endl;
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    int pooling_type = llama_pooling_type(ctx);

    // Get vocab
    const llama_vocab *vocab = llama_model_get_vocab(model);

    int32_t n_tokens_needed = -llama_tokenize(vocab, text.c_str(), text.length(), nullptr, 0, true, true);

    if (n_tokens_needed <= 0)
    {
        std::cerr << "Error: Failed to get token count" << std::endl;
        llama_free(ctx);
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }


    std::vector<llama_token> tokens(n_tokens_needed);
    int32_t n_tokens = llama_tokenize(vocab, text.c_str(), text.length(), tokens.data(), tokens.size(), true, true);

    if (n_tokens < 0)
    {
        std::cerr << "Error: Tokenization failed" << std::endl;
        llama_free(ctx);
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    tokens.resize(n_tokens);


    llama_batch batch = llama_batch_init(n_tokens, 0, 1);
    for (int i = 0; i < n_tokens; i++)
    {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = false;
    }
    batch.n_tokens = n_tokens;


    if (llama_encode(ctx, batch) != 0)
    {
        std::cerr << "Error: llama_encode() failed" << std::endl;
        llama_batch_free(batch);
        llama_free(ctx);
        llama_free_model(model);
        llama_backend_free();
        exit(1);
    }

    // std::cout << "Encoding successful" << std::endl;

    const float *emb = llama_get_embeddings_seq(ctx, 0);

    if (!emb)
    {
        std::cerr << "Trying fallback method..." << std::endl;
        emb = llama_get_embeddings(ctx);
        if (!emb)
        {
            std::cerr << "Error: Both embedding methods failed" << std::endl;
            llama_batch_free(batch);
            llama_free(ctx);
            llama_free_model(model);
            llama_backend_free();
            exit(1);
        }
    }

    int emb_dim = llama_n_embd(model);
    // std::cout << "Embedding dimension: " << emb_dim << std::endl;

    // std::cout << "Embedding:\n";
    // for (int i = 0; i < emb_dim; i++)
    // {
    //     std::cout << emb[i] << " ";
    // }
    // std::cout << "\n";
    std::vector<float> emb_vector(emb, emb + emb_dim);

    // Cleanup
    llama_batch_free(batch);
    llama_free(ctx);
    llama_free_model(model);
    llama_backend_free();
    return emb_vector;
}