#include <cstring>
#include <cstdlib>
#include <string>
#include <iostream>

#include "embed.hpp"
#include "search.hpp"
#include "utils/extract_search_query.hpp"
#include "model.hpp"
#include "api.h"

extern "C"
{
    const std::string embed_model_path = "/home/abancp/Projects/Lunar-Studio/models/all-MiniLM-L6-v2.F16.gguf";
    const std::string db_path = "/home/abancp/Projects/Lunar-Studio/ic/cs/mapping.db";
    const std::string index_path = "/home/abancp/Projects/Lunar-Studio/ic/cs/cpp_index_ivf.index";

    void load_llm(const char *model_path)
    {
        std::cout << "[API] Loading LLM from: " << model_path << std::endl;
        load_model(model_path);
        std::cout << "[API] LLM loaded successfully" << std::endl;
    }

    void generate(const char *prompt, C_TokenCallback cb)
    {
        std::cout << "\n[API] ========== NEW GENERATION REQUEST ==========\n";
        std::cout << "[API] Prompt: " << std::string(prompt).substr(0, 100) << "...\n";

        // -------- Safe C++ → C callback bridge --------
        TokenCallback cpp_cb = nullptr;

        if (cb != nullptr)
        {
            cpp_cb = [cb](const std::string &tok)
            {
                char *copy = strdup(tok.c_str());
                cb(copy);
                free(copy);
            };
        }

        // Convert prompt safely
        std::string prompt_cpp(prompt);

        // -------- PHASE 1: Ask model to decide if search is needed --------
        std::cout << "[API] Phase 1: Checking if search is needed...\n";

        std::string decision_response = run_model(prompt_cpp, true, {}, nullptr);

        std::cout << "[DEBUG] Phase 1 output : " << decision_response << std::endl;

        // Check if model wants to search
        bool needs_search = (decision_response.find("SEARCH") == 0);

        std::cout << "[API] Search needed: " << (needs_search ? "YES" : "NO") << "\n";

        if (needs_search)
        {
            // -------- PHASE 2: Extract search query and perform search --------
            std::cout << "[API] Phase 2: Extracting search query...\n";

            std::string search_query = decision_response.substr(7, decision_response.length() - 1);
            if (cpp_cb)
            {
                cpp_cb("Searching... : " + search_query);
            }
            // std::string search_query = extract_search_query(decision_response);
            std::cout << "[API] Search query: \"" << search_query << "\"\n";

            if (search_query.empty())
            {
                std::cerr << "[API] ERROR: Failed to extract search query\n";
                if (cpp_cb)
                {
                    cpp_cb("I apologize, but I encountered an error processing your search request. Please try rephrasing your question.");
                }
                return;
            }

            // Perform embedding and search
            std::cout << "[API] Generating embedding...\n";
            std::vector<float> query_embed = embed(search_query, embed_model_path.c_str());

            std::cout << "[API] Searching database...\n";
            std::vector<std::string> results = search(query_embed, db_path, index_path);

            std::cout << "[API] Retrieved " << results.size() << " results:\n";

            if (cpp_cb)
            {
                cpp_cb("Searched");
            }

            for (size_t i = 0; i < results.size() && i < 3; i++)
            {

                if (cpp_cb)
                {
                    cpp_cb(results[i].substr(0, 100));
                }
                std::cout << "  [" << i + 1 << "] "
                          << results[i].substr(0, 100) << "...\n";
            }

            // -------- PHASE 3: Generate answer using search results --------
            std::cout << "[API] Phase 3: Generating answer with search results...\n";

            // Ensure we have at least 3 results (pad with empty if needed)
            while (results.size() < 3)
            {
                results.push_back("[No additional information available]");
            }

            std::string final_response = run_model(
                prompt_cpp,
                false, // allowSearch = false
                results,
                cpp_cb // Stream tokens to user
            );

            std::cout << "[API] Final response generated (" << final_response.size() << " chars)\n";
        }
        else
        {
            // -------- No search needed: Direct response --------
            std::cout << "[API] Providing direct response (no search needed)\n";

            // The decision_response IS the answer, stream it if callback exists
            if (cpp_cb)
            {
                // Stream the response token by token
                for (char c : decision_response)
                {
                    cpp_cb(std::string(1, c));
                }
            }
        }

        std::cout << "[API] ========== GENERATION COMPLETE ==========\n\n";
    }
}