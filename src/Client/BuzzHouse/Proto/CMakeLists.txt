protobuf_generate_cpp(datastore_buzzhouse_proto_sources datastore_buzzhouse_proto_headers SQLGrammar.proto)

add_library(datastore_buzzhouse_proto ${datastore_buzzhouse_proto_headers} ${datastore_buzzhouse_proto_sources})
target_include_directories(datastore_buzzhouse_proto SYSTEM PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(datastore_buzzhouse_proto PUBLIC ch_contrib::protoc)
# Ignore warnings while compiling protobuf-generated *.pb.h and *.pb.cpp files.
target_compile_options(datastore_buzzhouse_proto PRIVATE "-w")
# Disable clang-tidy for protobuf-generated *.pb.h and *.pb.cpp files.
set_target_properties(datastore_buzzhouse_proto PROPERTIES CXX_CLANG_TIDY "")
