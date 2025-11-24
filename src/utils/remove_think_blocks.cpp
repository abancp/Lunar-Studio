#include <string>
#include "utils/remove_think_blocks.hpp"

void remove_think_blocks(std::string &s)
{
    const std::string start_tag = "<think>";
    const std::string end_tag = "</think>";

    while (true)
    {
        // find start
        size_t s_pos = s.find(start_tag);
        if (s_pos == std::string::npos)
            break; // no more <think>

        // find end
        size_t e_pos = s.find(end_tag, s_pos);
        if (e_pos == std::string::npos)
        {
            // malformed: remove everything from <think> to end
            s.erase(s_pos);
            break;
        }

        // remove <think> ... </think>
        s.erase(s_pos, (e_pos + end_tag.length()) - s_pos);
    }

    // optional: trim leading whitespace/newlines after removal
    while (!s.empty() && (s[0] == '\n' || s[0] == ' '))
        s.erase(s.begin());
}