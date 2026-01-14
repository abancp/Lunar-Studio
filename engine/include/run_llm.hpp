#include <string>
#include <vector>
#include <functional>

using TokenCallback = std::function<void(const std::string &)>;

void load_model(const char *model_path);
std::string run_model(std::string prompt, const char *model_path, bool, std::vector<std::string>, TokenCallback token_callback = nullptr);
