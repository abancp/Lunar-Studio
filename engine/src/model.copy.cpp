#include "model.hpp"
#include "llama.h"
#include "utils/remove_think_blocks.hpp"
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
#include <vector>
#include <atomic>

llama_model *g_model = nullptr;
static const llama_vocab *g_vocab = nullptr;
static llama_model_params g_model_params;
static llama_context_params g_ctx_params;

// for actual answer context
static llama_sampler *g_sampler = nullptr;
static llama_context *g_ctx;
static std::vector<llama_chat_message> g_messages;
// Track how many tokens are already in KV cache
static int g_cached_tokens = 0;
// Track prompt tokens separately to detect mismatches
static std::vector<llama_token> g_cached_prompt_tokens;

// for actual tools context
static llama_sampler *g_tools_sampler = nullptr;
static llama_context *g_tools_ctx;
static std::vector<llama_chat_message> g_tools_messages;
static int g_cached_tokens_tools = 0;
static std::vector<llama_token> g_cached_prompt_tokens_tools;

// atomic interrupt of generating
std::atomic<bool> pause_generation_interrupt = false;

// STABLE system prompt that NEVER changes
static const char *STABLE_SYSTEM_PROMPT =
    R"SYS(You are LunarStudio, created by Aban Muhammed (AI Researcher & Engineer).
You are a helpful AI assistant capable of answering questions and searching for information when needed.
Always provide structured formatted with # Heading , ##Subheading , **BOLD** ,-lists , tables ,etc formatted and helpful responses.)SYS";

static const char *STABLE_SYSTEM_PROMPT_TOOLS =
    R"(Decide if the USER_MSG requires external factual information . 
If not, output: NO_SEARCH
If yes, output: SEARCH: <query>

Rules:
- The query must be a optimized content rich query.
- Do not expand the query beyond the essential concept.
- Look at the history and also any relevent chat already there
- Example , USER : did you know about logarithms -> SEARCH : What is logarithms
- Output exactly one line. Never answer the user.
USER_MSG: )";

// Load Model first
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
  // TODO: dynamic params depends user Hardware
  g_ctx_params = llama_context_default_params();
  // g_ctx_params.n_ctx = 2048 * 4;
  g_ctx_params.n_ctx = 2048 * 2;
  g_ctx_params.n_batch = 1024;
  g_ctx_params.n_threads = std::thread::hardware_concurrency();
  g_ctx_params.n_threads_batch = std::thread::hardware_concurrency();

  g_ctx = llama_init_from_model(g_model, g_ctx_params);
  g_tools_ctx = llama_init_from_model(g_model, g_ctx_params);

  g_sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(g_sampler, llama_sampler_init_min_p(0.05f, 1));
  llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(0.7f));
  llama_sampler_chain_add(g_sampler,
                          llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  g_tools_sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(g_tools_sampler, llama_sampler_init_min_p(0.05f, 1));
  llama_sampler_chain_add(g_tools_sampler, llama_sampler_init_temp(0.7f));
  llama_sampler_chain_add(g_tools_sampler,
                          llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  g_cached_tokens = 0;
  g_cached_prompt_tokens.clear();

  g_cached_tokens_tools = 0;
  g_cached_prompt_tokens_tools.clear();

  // Initialize with stable system prompt
  g_messages.push_back({"system", STABLE_SYSTEM_PROMPT});

  g_tools_messages.push_back({"system", STABLE_SYSTEM_PROMPT_TOOLS});

  std::cout << "[DEBUG] Model loaded successfully\n";

  return 0;
}

static std::string build_prompt_from_history(std::vector<llama_chat_message> messages)
{
  const char *tmpl = llama_model_chat_template(g_model, nullptr);

  if (!tmpl)
    throw std::runtime_error("Chat template missing");

  std::vector<char> out(8192); // Increased buffer size

  int n = llama_chat_apply_template(tmpl, messages.data(), messages.size(),
                                    true, out.data(), out.size());

  if (n > (int)out.size())
  {
    out.resize(n + 1024);
    n = llama_chat_apply_template(tmpl, messages.data(), messages.size(),
                                  true, out.data(), out.size());
  }

  if (n < 0)
    throw std::runtime_error("Failed applying chat template");

  return std::string(out.data(), n);
}

// Helper: Build search instruction prompt
static std::string build_search_instruction(const std::string &user_prompt)
{
  return R"(Decide if the USER_MSG requires external factual information . 
If not, output: NO_SEARCH
If yes, output: SEARCH: <query>

Rules:
- The query must be a optimized content rich query.
- Do not expand the query beyond the essential concept.
- Look at the history and also any relevent chat already there
- Output exactly one line. Never answer the user.
- Only search if external information needed . dont search for any calculation or doing tasks like format answer , shorten answer...
USER_MSG:
 )" +
         user_prompt;
}

// Helper: Build answering instruction prompt
static std::string build_answer_instruction(const std::string &user_prompt,
                                            std::vector<std::string> &search_results)
{
  if (search_results.size() > 0)
  {
    std::string instruction =
        R"(
        Answer the question using the provided search results below if only SEARCH_RESULTS contains the answer for the question.

        INSTRUCTIONS:
        - Synthesize information clearly and concisely
        - If results don't contain the answer, say your answer
        - You must always answer in a clear, structured format. Use headings, subheadings, bullet points, short paragraphs, and examples when appropriate. Respond professionally and avoid long unstructured text.
        QUESTION:
        )" +
        user_prompt + "\n\nSEARCH RESULTS:\n";

    for (size_t i = 0; i < (search_results.size() > 3 ? 3 : search_results.size()); i++)
    {
      instruction +=
          "[" + std::to_string(i + 1) + "] " + search_results[i] + "\n\n";
    }

    instruction += "  -  Give formtted well structured answers";

    return instruction;
  }
  else
  {
    std::string instruction = R"(System : You are a helpfull ai assistand 
      You must always answer in a clear, structured format.
          Use headings, subheadings, bullet points, short paragraphs, and examples when appropriate.
          Respond professionally and avoid long unstructured text.
        User :
        )" + user_prompt;
    return instruction;
  }
}

std::string llm_inference(
    const std::string &prompt,
    std::vector<llama_chat_message> &messages,
    llama_context *&ctx,
    llama_context_params &ctx_params,
    llama_vocab *vocab,
    llama_sampler *smplr,
    int &cached_tokens,
    std::vector<llama_token> &cached_prompt_tokens,
    llama_model *model,
    bool allowSearch,
    TokenCallback cb)
{
  messages.push_back({"user", strdup(prompt.c_str())});
  pause_generation_interrupt.store(false);

  std::cout << "[DEBUG] Total messages in history: " << messages.size() << "\n";

  std::string final_prompt = build_prompt_from_history(messages);
  std::cout << "[DEBUG] Final prompt length: " << final_prompt.size() << " chars\n";
  std::cout << "[DEBUG] Final prompt : " << final_prompt << " chars\n";

  if (!ctx)
  {
    std::cerr << "[ERROR] Context is null!\n";
    return "";
  }

  bool is_first = true;
  int n = -llama_tokenize(vocab, final_prompt.c_str(), final_prompt.size(),
                          nullptr, 0, is_first, true);

  if (n < 0)
  {
    std::cerr << "[ERROR] Tokenization failed\n";
    return "";
  }

  std::vector<llama_token> toks(n);
  llama_tokenize(vocab, final_prompt.c_str(), final_prompt.size(),
                 toks.data(), toks.size(), is_first, true);

  std::cout << "[DEBUG] Total tokens: " << toks.size()
            << ", Cached: " << cached_tokens << "\n";

  bool cache_valid = (cached_tokens > 0 && cached_tokens <= (int)toks.size());

  if (cache_valid)
  {
    for (int i = 0;
         i < cached_tokens && i < (int)cached_prompt_tokens.size(); i++)
    {

      if (toks[i] != cached_prompt_tokens[i])
      {
        std::cout << "[WARNING] Token mismatch at position "
                  << i << ". Invalidating cache.\n";
        cache_valid = false;
        break;
      }
    }
  }
  else if (cached_tokens > (int)toks.size())
  {
    std::cout << "[WARNING] Cache tokens > actual tokens. Invalidating.\n";
    cache_valid = false;
  }

  if (!cache_valid && cached_tokens > 0)
  {
    std::cout << "[DEBUG] Recreating context...\n";
    llama_free(ctx);
    ctx = llama_init_from_model(model, ctx_params);
    llama_sampler_reset(smplr);

    cached_tokens = 0;
    cached_prompt_tokens.clear();
  }

  int tokens_to_process = toks.size() - cached_tokens;
  std::cout << "[DEBUG] Tokens to process: " << tokens_to_process << "\n";

  if (tokens_to_process > 0)
  {
    llama_batch batch =
        llama_batch_get_one(toks.data() + cached_tokens, tokens_to_process);

    if (llama_decode(ctx, batch) != 0)
    {
      std::cerr << "[ERROR] Failed to decode batch\n";
      return "";
    }

    cached_tokens = toks.size();
    cached_prompt_tokens = toks;
  }

  std::string raw_response;
  int generated_tokens = 0;

  while (true)
  {
    // if (pause_generation_interrupt.load())
    // {
    //   break;
    // }

    llama_token tok = llama_sampler_sample(smplr, ctx, -1);

    char buf[256];
    int n = llama_token_to_piece(vocab, tok, buf, sizeof(buf), 0, true);

    if (n < 0)
      break;

    std::string piece(buf, n);
    raw_response += piece;
    generated_tokens++;

    if (llama_vocab_is_eog(vocab, tok))
      break;

    if (cb)
    {
      bool is_search_call =
          (allowSearch && raw_response.find("search(") != std::string::npos);

      if (!is_search_call)
        cb(piece);
    }

    llama_batch batch = llama_batch_get_one(&tok, 1);
    if (llama_decode(ctx, batch) != 0)
      break;

    cached_tokens++;
  }

  return raw_response;
}

std::string run_model(std::string prompt, bool allowSearch,
                      std::vector<std::string> search_results,
                      TokenCallback cb)
{
  std::cout << "[DEBUG] ========== NEW TURN ==========\n";
  std::cout << "[DEBUG] Mode: "
            << (allowSearch ? "SEARCH_DECISION" : "ANSWER_WITH_RESULTS")
            << "\n";
  std::cout << "[DEBUG] User prompt: " << prompt.substr(0, 100) << "...\n";

  std::string user_message;
  std::string raw_response;
  if (allowSearch)
  {
    // user_message = build_search_instruction(prompt);
    raw_response = llm_inference(
        prompt,
        g_tools_messages,
        g_tools_ctx,
        g_ctx_params,
        const_cast<llama_vocab *>(g_vocab),
        g_tools_sampler,
        g_cached_tokens_tools,
        g_cached_prompt_tokens_tools,
        g_model,
        allowSearch,
        cb);
  }
  else
  {
    user_message = build_answer_instruction(prompt, search_results);
    raw_response = llm_inference(
        user_message,
        g_messages,
        g_ctx,
        g_ctx_params,
        const_cast<llama_vocab *>(g_vocab),
        g_sampler,
        g_cached_tokens,
        g_cached_prompt_tokens,
        g_model,
        allowSearch,
        cb);
  }

  std::cout << "[DEBUG] Total cached tokens after generation: "
            << g_cached_tokens << "\n";
  std::cout << "[DEBUG] Total cached tokens after generation (tools) : "
            << g_cached_tokens_tools << "\n";
  std::cout << "[DEBUG] Raw response length: " << raw_response.size()
            << " chars\n";

  remove_think_blocks(raw_response);
  std::string response_for_history = raw_response;
  std::cout << "[DEBUG] Cleaned response length: " << raw_response.size()
            << " chars\n";
  if (allowSearch)
  {
    g_tools_messages.push_back({"assistant", strdup(response_for_history.c_str())});
  }
  else
  {
    g_tools_messages.push_back({"assistant", strdup(response_for_history.c_str())});
    g_messages.push_back({"assistant", strdup(response_for_history.c_str())});
  }
  std::cout << "[DEBUG] ========== TURN END ==========\n\n";

  return raw_response;
}

std::string generate(std::string system_prompt,std::string prompt)
{
  std::vector<llama_chat_message> messages;
  messages.push_back({"system",system_prompt.c_str()});
  std::string raw_response = llm_inference(
      prompt,
      messages,
      g_ctx,
      g_ctx_params,
      const_cast<llama_vocab *>(g_vocab),
      g_sampler,
      g_cached_tokens,
      g_cached_prompt_tokens,
      g_model,
      false,
      nullptr);
    return raw_response;
}

std::vector<llama_chat_message> get_context()
{
  return g_messages;
}

void request_pause()
{
  pause_generation_interrupt.store(true);
}