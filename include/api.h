#ifndef LUNARSTUDIO_API_H
#define LUNARSTUDIO_API_H

#ifdef __cplusplus
extern "C"
{
#endif
    typedef void (*C_TokenCallback)(const char *);
    void load_llm();
    void generate(const char *prompt, C_TokenCallback callback);
#ifdef __cplusplus
}
#endif
#endif