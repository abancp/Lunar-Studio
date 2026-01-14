import ctypes
import os
import sys

# Path to your compiled .so
# Use absolute path to avoid confusion
LIB_PATH = "/home/abancp/Projects/localGPT1.0/build/liblunarstudio.so"

if not os.path.exists(LIB_PATH):
    raise FileNotFoundError(f".so not found at: {LIB_PATH}")

# Load the shared library
lib = ctypes.CDLL(LIB_PATH)

# C function signatures
CALLBACK = ctypes.CFUNCTYPE(None, ctypes.c_char_p)

# load_llm(): void load_llm();
lib.load_llm.argtypes = []
lib.load_llm.restype = None

# generate(): void generate(const char*, void(*cb)(const char*));
lib.generate.argtypes = [ctypes.c_char_p, CALLBACK]
lib.generate.restype = None


# -------- Token callback from C/C++ --------
def on_token(ptr):
    if not ptr:
        return
    # get raw bytes
    raw = ctypes.cast(ptr, ctypes.c_char_p).value
    # print later after full token stream is complete
    sys.stdout.buffer.write(raw)
    sys.stdout.flush()



callback = CALLBACK(on_token)


# -------- Run test --------
print("Loading LLM model...")
lib.load_llm()
print("Model loaded.")
while True:
    prompt = input()
    prompt = prompt.encode()
    if not prompt:
        break

    print("\nGenerating:")
    lib.generate(prompt, callback)

print("\nDone.")
