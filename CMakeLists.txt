cmake_minimum_required(VERSION 3.16)
project(localGPT LANGUAGES CXX)

# ============================================================
# 🧱 Project Configuration
# ============================================================
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_BUILD_TYPE Release)

# ============================================================
# 📦 Dependencies
# ============================================================
# You already installed these system-wide under /usr/local
#   • llama.cpp (libllama.a or .so)
#   • FAISS (libfaiss.a or .so)
#   • SQLite3
#   • OpenBLAS + LAPACK
#   • OpenMP
#   • nlohmann-json (header-only)

include_directories(/usr/local/include)
link_directories(/usr/local/lib)

# SQLite
find_package(SQLite3 REQUIRED)
include_directories(${SQLite3_INCLUDE_DIRS})

# OpenMP (used by FAISS)
find_package(OpenMP REQUIRED)

# BLAS / LAPACK (used by FAISS)
find_package(BLAS REQUIRED)
find_package(LAPACK REQUIRED)

# ============================================================
# 🧩 Include nlohmann-json (header-only)
# ============================================================
# For Arch: sudo pacman -S nlohmann-json
# Header is available as <nlohmann/json.hpp>
find_path(JSON_INCLUDE_DIR nlohmann/json.hpp)
if (NOT JSON_INCLUDE_DIR)
    message(FATAL_ERROR "nlohmann/json.hpp not found. Install with: sudo pacman -S nlohmann-json")
endif()
include_directories(${JSON_INCLUDE_DIR})

# ============================================================
# ⚙️ Build targets
# ============================================================

# -----------------------------
# Main executable: localGPT
# -----------------------------
add_executable(localGPT
  src/main.cpp
  src/embed.cpp
  src/search.cpp
  src/run_llm.cpp
)

target_include_directories(localGPT PRIVATE include)
target_link_libraries(localGPT PRIVATE
    llama
    faiss
    ${SQLite3_LIBRARIES}
    ${OpenMP_CXX_LIBRARIES}
    ${BLAS_LIBRARIES}
    ${LAPACK_LIBRARIES}
)
target_compile_options(localGPT PRIVATE -O3 -march=native ${OpenMP_CXX_FLAGS})
install(TARGETS localGPT DESTINATION bin)

# -----------------------------
# Secondary executable: make_index
# -----------------------------
add_executable(make_index
  src/make_index.cpp
  src/embed.cpp
)

target_include_directories(make_index PRIVATE include)
target_link_libraries(make_index PRIVATE
    llama
    faiss
    ${SQLite3_LIBRARIES}
    ${OpenMP_CXX_LIBRARIES}
    ${BLAS_LIBRARIES}
    ${LAPACK_LIBRARIES}
)
target_compile_options(make_index PRIVATE -O3 -march=native ${OpenMP_CXX_FLAGS})
install(TARGETS make_index DESTINATION bin)

# ============================================================
# ✅ Optional: clean deprecation warnings from llama.cpp
# ============================================================
target_compile_options(localGPT PRIVATE -Wno-deprecated-declarations)
target_compile_options(make_index PRIVATE -Wno-deprecated-declarations)
