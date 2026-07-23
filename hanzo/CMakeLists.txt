# The Hanzo Research C++ client — a self-contained, vendorable unit (research.hpp +
# research.cpp) any native producer (a kernel, a benchmark, the datastore/luxcpp stack)
# links to record R&D evidence on /v1/research. The record-serialization + provenance core
# is dependency-free; the HTTP transport is the one swappable seam. libcurl is the
# production transport (TLS to api.hanzo.ai), vendored in this tree at contrib/curl.
cmake_minimum_required(VERSION 3.16)
project(hanzo_research CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(HANZO_RESEARCH_CURL "Compile the libcurl HTTP transport (needs libcurl)" ON)

add_library(research STATIC research.cpp)
target_include_directories(research PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_options(research PRIVATE -Wall -Wextra)

if(HANZO_RESEARCH_CURL)
  find_package(CURL REQUIRED)
  target_link_libraries(research PUBLIC CURL::libcurl)
  target_compile_definitions(research PUBLIC HANZO_RESEARCH_CURL)
endif()

# The falsifiable self-checking example: SHA-256 known-answer + a kernel-perf run concluded
# Proven and a marketing-experiment concluded Refuted, over an injected capture transport.
add_executable(research_example research_example.cpp)
target_link_libraries(research_example PRIVATE research)
# Designated initializers intentionally omit defaulted Options/Result fields (the ergonomic
# surface); GCC's -Wmissing-field-initializers is a false positive there.
target_compile_options(research_example PRIVATE -Wall -Wextra -Wno-missing-field-initializers)

enable_testing()
add_test(NAME research_selftest COMMAND research_example)
