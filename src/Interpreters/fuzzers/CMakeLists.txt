datastore_add_executable(execute_query_fuzzer execute_query_fuzzer.cpp)
target_link_libraries(execute_query_fuzzer PRIVATE
    dbms
    datastore_table_functions
    datastore_aggregate_functions
    datastore_functions
    datastore_dictionaries
    datastore_dictionaries_embedded)
