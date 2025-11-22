#include <cstring>
#include <cstdlib>
#include <string>
#include <iostream>

#include "model.hpp"
#include "api.h"

extern "C"
{
    // Adjust this if needed
    const char *model_path = "/home/abancp/Projects/localGPT1.0/models/Qwen3-0.6B-Q4_K_M.gguf";

    void load_llm()
    {
        load_model(model_path);
    }

    void generate(const char *prompt, C_TokenCallback cb)
    {
        std::cout << "[C++] Starting generation..." << std::endl;

        // -------- Safe C++ → C callback bridge --------
        TokenCallback cpp_cb = nullptr;

        if (cb != nullptr)
        {
            cpp_cb = [cb](const std::string &tok)
            {
                char *copy = strdup(tok.c_str()); // safe heap buffer
                cb(copy);                         // call Python/Flutter
                free(copy);                       // release after callback
            };
        }

        // Convert prompt safely
        std::string prompt_cpp(prompt);

        std::cout << "[C++] Calling run_model..." << std::endl;

        // -------- Call your LLM engine --------
        run_model(prompt_cpp, model_path, true, {}, cpp_cb);

        std::cout << "[C++] Generation complete" << std::endl;
    }
}
