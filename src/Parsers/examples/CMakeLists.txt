set(SRCS)

datastore_add_executable(lexer lexer.cpp ${SRCS})
target_link_libraries(lexer PRIVATE datastore_parsers datastore_common_config)

datastore_add_executable(select_parser select_parser.cpp ${SRCS} "../../Server/ServerType.cpp")
target_link_libraries(select_parser PRIVATE dbms)

datastore_add_executable(create_parser create_parser.cpp ${SRCS} "../../Server/ServerType.cpp")
target_link_libraries(create_parser PRIVATE dbms)

datastore_add_executable(parser_memory_profiler parser_memory_profiler.cpp ${SRCS} "../../Server/ServerType.cpp")
target_link_libraries(parser_memory_profiler PRIVATE dbms)
