#pragma once
#include <string>
#include <vector>
#include "model.hpp"
#include "llama.h"

struct StreamState
{
    std::string buffer;
    TokenCallback cb;
    std::string fullResponse;
};

std::string external_api_generate(const char *api_key, std::string model, std::vector<llama_chat_message> messages,TokenCallback cb);