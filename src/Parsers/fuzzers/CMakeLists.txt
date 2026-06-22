datastore_add_executable(lexer_fuzzer lexer_fuzzer.cpp ${SRCS})
target_link_libraries(lexer_fuzzer PRIVATE datastore_parsers)

datastore_add_executable(select_parser_fuzzer select_parser_fuzzer.cpp ${SRCS})
target_link_libraries(select_parser_fuzzer PRIVATE datastore_parsers datastore_functions dbms)

datastore_add_executable(create_parser_fuzzer create_parser_fuzzer.cpp ${SRCS})
target_link_libraries(create_parser_fuzzer PRIVATE datastore_parsers datastore_functions dbms)

add_subdirectory(codegen_fuzzer)

