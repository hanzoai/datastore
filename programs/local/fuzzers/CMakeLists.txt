datastore_add_executable(datastore_fuzzer datastore_fuzzer.cpp)
target_include_directories (datastore_fuzzer PRIVATE ..)

target_link_libraries(datastore_fuzzer PRIVATE clickhouse-local-lib)

target_link_libraries(datastore_fuzzer PRIVATE common dbms)

if (TARGET ch_contrib::jemalloc)
    target_link_libraries(datastore_fuzzer PRIVATE ch_contrib::jemalloc)
endif()
