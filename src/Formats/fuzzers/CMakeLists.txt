datastore_add_executable(format_fuzzer format_fuzzer.cpp ${SRCS})
target_link_libraries(format_fuzzer PRIVATE datastore_aggregate_functions dbms)
