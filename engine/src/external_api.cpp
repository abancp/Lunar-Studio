#include "external_api.hpp"
#include "llama.h"

#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <iostream>
#include <string>

static size_t write_callback(char *ptr, size_t size, size_t nmemb,
                             void *userdata)
{
  const size_t total = size * nmemb;
  auto *state = static_cast<StreamState *>(userdata);

  // Append raw bytes (DO NOT assume UTF-8)
  state->buffer.append(ptr, total);

  size_t pos;
  while ((pos = state->buffer.find('\n')) != std::string::npos)
  {
    try
    {

      std::string line = state->buffer.substr(0, pos);
      state->buffer.erase(0, pos + 1);

      // Only process SSE data frames
      if (line.rfind("data: ", 0) != 0)
        continue;

      std::string payload = line.substr(6);

      if (payload == "[DONE]")
        return total;

      // Groq/OpenAI always send JSON objects here
      if (payload.empty() || payload[0] != '{')
        continue;

      // Non-throwing JSON parse (CRITICAL)
      nlohmann::json j = nlohmann::json::parse(payload, nullptr, false);
      if (j.is_discarded())
        continue;

      const auto jsonString = j.dump();
      std::cout << "Json : " << jsonString << "\n";

      if (!j.contains("choices"))
      {
        std::cout << "choices not found\n";
        continue;
      }
      auto &choices = j["choices"];
      if (!choices.is_array() || choices.empty())
        continue;

      auto &delta = choices[0]["delta"];
      if (!delta.is_object() || !delta.contains("content"))
        continue;

      // IMPORTANT:
      // get_ref DOES NOT validate UTF-8 (safe for streaming)

      const auto &content =
          delta["content"].get_ref<const nlohmann::json::string_t &>();

      state->fullResponse.append(content);

      if (state->cb)
        state->cb(content);
    }
    catch (...)
    {
      std::cout << "Error\n";
    }
  }

  return total;
}

std::string external_api_generate(const char *api_key, std::string model,
                                  std::vector<llama_chat_message> messages,
                                  TokenCallback cb)
{
  if (!api_key)
  {
    std::cerr << "Error: GROQ_API_KEY not set\n";
    return "";
  }

  CURL *curl = curl_easy_init();
  if (!curl)
  {
    std::cerr << "Error: curl init failed\n";
    return "";
  }

  // Build request body
  nlohmann::json body;
  body["model"] = model;
  body["stream"] = true;
  body["messages"] = nlohmann::json::array();

  for (const auto &msg : messages)
  {
    body["messages"].push_back({{"role", msg.role}, {"content", msg.content}});
  }

  const std::string request_body = body.dump();

  // Headers
  struct curl_slist *headers = nullptr;
  headers = curl_slist_append(headers, "Content-Type: application/json");
  headers = curl_slist_append(
      headers, ("Authorization: Bearer " + std::string(api_key)).c_str());

  StreamState state{};
  state.cb = cb;

  curl_easy_setopt(curl, CURLOPT_URL,
                   "https://api.groq.com/openai/v1/chat/completions");
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, request_body.c_str());

  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &state);

  // ---- REQUIRED STABILITY OPTIONS ----
  curl_easy_setopt(curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
  curl_easy_setopt(curl, CURLOPT_CAINFO, "/etc/ssl/certs/ca-certificates.crt");
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 0L);
  curl_easy_setopt(curl, CURLOPT_TCP_KEEPALIVE, 1L);

  // Enable only while debugging
  curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

  CURLcode res = curl_easy_perform(curl);
  if (res != CURLE_OK)
  {
    std::cerr << "libcurl error: " << curl_easy_strerror(res) << "\n";
  }

  curl_slist_free_all(headers);
  curl_easy_cleanup(curl);

  return state.fullResponse;
}
