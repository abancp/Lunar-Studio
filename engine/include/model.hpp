#include "llama.h"
#include <functional>
#include <string>
#include <vector>

using TokenCallback = std::function<void(const std::string &)>;

int load_model(const char *model_path);
std::string run_model(std::string prompt, bool, std::vector<std::string>,
                      TokenCallback token_callback = nullptr);
std::vector<llama_chat_message> get_context();
