cmake_minimum_required(VERSION 3.16)
project(LunarStudio LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_BUILD_TYPE Release)

include_directories(/usr/local/include)
link_directories(/usr/local/lib)

find_package(SQLite3 REQUIRED)
include_directories(${SQLite3_INCLUDE_DIRS})

find_package(OpenMP REQUIRED)
find_package(BLAS REQUIRED)
find_package(LAPACK REQUIRED)

# JSON
find_path(JSON_INCLUDE_DIR nlohmann/json.hpp)
if (NOT JSON_INCLUDE_DIR)
    message(FATAL_ERROR "nlohmann/json.hpp not found.")
endif()
include_directories(${JSON_INCLUDE_DIR})

#add_executable(LunarStudio
#    src/main.cpp
#    src/embed.cpp
#    src/search.cpp
#    src/model.cpp
#    src/utils/extract_search_query.cpp
#)
#
#target_include_directories(LunarStudio PRIVATE include)
#target_include_directories(LunarStudio PRIVATE include/utils)
#
#target_link_libraries(LunarStudio PRIVATE
#    llama
#    faiss
#    ggml
#    ggml-base
#    ${SQLite3_LIBRARIES}
#    ${OpenMP_CXX_LIBRARIES}
#    ${BLAS_LIBRARIES}
#    ${LAPACK_LIBRARIES}
#)
#
#target_compile_options(LunarStudio PRIVATE -O3 -march=native ${OpenMP_CXX_FLAGS})
#
#install(TARGETS LunarStudio DESTINATION bin)



add_library(lunarstudio SHARED
    src/api.cpp
    src/embed.cpp
    src/search.cpp
    src/model.cpp
    src/utils/extract_search_query.cpp
    src/utils/remove_think_blocks.cpp
)

target_include_directories(lunarstudio PUBLIC include)
target_include_directories(lunarstudio PRIVATE include/utils)

target_link_libraries(lunarstudio PUBLIC
    llama
    faiss
    ${SQLite3_LIBRARIES}
    ${OpenMP_CXX_LIBRARIES}
    ${BLAS_LIBRARIES}
    ${LAPACK_LIBRARIES}
)

target_compile_options(lunarstudio PRIVATE -O3 -march=native ${OpenMP_CXX_FLAGS})

install(TARGETS lunarstudio DESTINATION lib)

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

foreach(target make_index lunarstudio)
    target_compile_options(${target} PRIVATE -Wno-deprecated-declarations)
endforeach()
