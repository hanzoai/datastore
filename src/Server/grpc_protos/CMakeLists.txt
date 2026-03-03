PROTOBUF_GENERATE_GRPC_CPP(datastore_grpc_proto_sources datastore_grpc_proto_headers datastore_grpc.proto)

add_library(datastore_grpc_protos ${datastore_grpc_proto_headers} ${datastore_grpc_proto_sources})
target_include_directories(datastore_grpc_protos SYSTEM PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries (datastore_grpc_protos PUBLIC ch_contrib::grpc)
# Ignore warnings while compiling protobuf-generated *.pb.h and *.pb.cpp files.
target_compile_options(datastore_grpc_protos PRIVATE "-w")
# Disable clang-tidy for protobuf-generated *.pb.h and *.pb.cpp files.
set_target_properties(datastore_grpc_protos PROPERTIES CXX_CLANG_TIDY "")
