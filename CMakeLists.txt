cmake_minimum_required(VERSION 3.16)
project(LunarStudio LANGUAGES CXX)

# ============================================================
# 🧱 Project Configuration
# ============================================================
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_BUILD_TYPE Release)

# ============================================================
# 📦 Dependencies (FAISS / SQLite / BLAS / llama.cpp)
# ============================================================
include_directories(/usr/local/include)
link_directories(/usr/local/lib)

# SQLite
find_package(SQLite3 REQUIRED)
include_directories(${SQLite3_INCLUDE_DIRS})

# OpenMP (FAISS uses)
find_package(OpenMP REQUIRED)

# BLAS + LAPACK
find_package(BLAS REQUIRED)
find_package(LAPACK REQUIRED)



# JSON
find_path(JSON_INCLUDE_DIR nlohmann/json.hpp)
if (NOT JSON_INCLUDE_DIR)
    message(FATAL_ERROR "nlohmann/json.hpp not found.")
endif()
include_directories(${JSON_INCLUDE_DIR})

# ============================================================
# 📦 Qt 6 (QML + Quick)
# ============================================================
find_package(Qt6 6.2 REQUIRED COMPONENTS Quick Qml Gui)

# Enable Qt autogen features
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Fix QML access path (no /qt/qml prefix)
qt_policy(SET QTP0001 NEW)

# ============================================================
# ⚙️ Backend Executables
# ============================================================

# ---- LunarStudio (CLI)
add_executable(LunarStudio
    src/main.cpp
    src/embed.cpp
    src/search.cpp
    src/run_llm.cpp
    src/utils/extract_search_query.cpp
)

target_include_directories(LunarStudio PRIVATE include)
target_include_directories(LunarStudio PRIVATE include/utils)
target_link_libraries(LunarStudio PRIVATE
    llama
    faiss
    ${SQLite3_LIBRARIES}
    ${OpenMP_CXX_LIBRARIES}
    ${BLAS_LIBRARIES}
    ${LAPACK_LIBRARIES}
)
target_compile_options(LunarStudio PRIVATE -O3 -march=native ${OpenMP_CXX_FLAGS})

install(TARGETS LunarStudio DESTINATION bin)


# ---- make_index (CLI)
add_executable(make_index
    src/make_index.cpp
    src/embed.cpp
)

target_include_directories(make_index PRIVATE include)
target_include_directories(make_index PRIVATE include/utils)
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
# ⚙️ Qt GUI Executable + QML Module
# ============================================================

qt_add_executable(LunarStudio_gui
    src/gui_main.cpp
)

# **IMPORTANT: use relative paths inside your source tree**
qt_add_qml_module(LunarStudio_gui
    URI LunarStudioUI
    VERSION 1.0
    RESOURCE_PREFIX "/"                 # ensures qrc:/LunarStudioUI/ path
    QML_FILES
        src/qml/Main.qml                    # use RELATIVE PATH, NOT absolute
)

target_link_libraries(LunarStudio_gui PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Gui
    llama
    faiss
    ${SQLite3_LIBRARIES}
    ${OpenMP_CXX_LIBRARIES}
    ${BLAS_LIBRARIES}
    ${LAPACK_LIBRARIES}
)

target_compile_options(LunarStudio_gui PRIVATE -O3 -march=native ${OpenMP_CXX_FLAGS})


# ============================================================
# ⚠️ Deprecation warnings from llama.cpp
# ============================================================
foreach(target LunarStudio make_index LunarStudio_gui)
    target_compile_options(${target} PRIVATE -Wno-deprecated-declarations)
endforeach()
