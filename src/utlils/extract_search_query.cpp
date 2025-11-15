#include <string>
#include <regex>

std::string extract_search_query(const std::string &output)
{
    std::regex pattern(R"(search\s*\(\s*["']([^"']+)["']\s*\))");
    std::smatch match;

    if (std::regex_search(output, match, pattern))
    {
        return match[1];
    }

    return "";
}
