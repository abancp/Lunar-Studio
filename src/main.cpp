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

int main()
{
    const std::string embed_mode_path = "models/all-MiniLM-L6-v2.F16.gguf";
    const std::string llm_model_path = "models/qwen2.5-0.5b-instruct-q8_0.gguf";
    const std::string db_path = "ic/cs/mapping.db";
    const std::string index_path = "ic/cs/knowledge/cpp_index_ivf.index";
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
