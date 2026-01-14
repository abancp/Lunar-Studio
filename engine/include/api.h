#ifndef LUNARSTUDIO_API_H
#define LUNARSTUDIO_API_H

#ifdef __cplusplus
extern "C" {
#endif
struct ChatEntryC {
  const char *role;
  const char *message;
};

struct ChatArrayC {
  ChatEntryC *items;
  size_t size;
};

typedef void (*C_TokenCallback)(const char *);
void load_llm(const char *model_path);
void generate(const char *prompt, C_TokenCallback callback);
ChatArrayC get_context_c();
void pause_generation();
#ifdef __cplusplus
}
#endif
#endif
