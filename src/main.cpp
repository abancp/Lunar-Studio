#include <iostream>
#include <vector>
#include <cmath>
#include <string>
#include <embed.hpp>
#include <search.hpp>
#include "run_llm.hpp"
#include <fstream>
#include <nlohmann/json.hpp>
#include <string>
#include <extract_search_query.hpp>
#include "llama.h"

enum llama_log_level
{
    LLAMA_LOG_LEVEL_ERROR = 2,
    LLAMA_LOG_LEVEL_WARN = 3,
    LLAMA_LOG_LEVEL_INFO = 4,
    LLAMA_LOG_LEVEL_DEBUG = 5,
};

static void silent_logger(enum ggml_log_level level, const char *text, void *user_data)
{
    // Do nothing → completely silent
}

int main()
{
    llama_log_set(silent_logger, nullptr);
    const std::string embed_mode_path = "models/all-MiniLM-L6-v2.F16.gguf";
    const std::string llm_model_path = "models/Qwen3-0.6B-Q8_0.gguf";
    const std::string db_path = "ic/cs/mapping.db";
    const std::string index_path = "ic/cs/cpp_index_ivf.index";
    std::string query;
    std::cout << "Prompt : ";
    std::getline(std::cin, query);
    std::string res = run_model(query, llm_model_path.c_str(), true, {});
    std::cout << "MODEL : " << res;

    if (res.find("search(") != std::string::npos)
    {
        std::string search_query = extract_search_query(res);
        std::vector<float> query_embed = embed(search_query, embed_mode_path.c_str());
        std::vector<std::string> results = search(query_embed, db_path, index_path);
        for (int i = 0; i < results.size(); i++)
        {
            std::cout << "[ " << i << " ]" << " : " << results[i] << "\n";
        }

        res = run_model(query, llm_model_path.c_str(), false, results);
    }
}
