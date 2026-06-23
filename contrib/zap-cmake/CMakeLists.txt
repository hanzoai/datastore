# ZAP (Zero-Copy App Proto) — zap-proto/cpp-core, the debranded Cap'n-Proto-derived
# C++ codec + RPC. Replaces the old capnproto contrib: it serves BOTH the CapnProto
# data format (zap:: dynamic reflection) AND the native ZAP query transport (zap-rpc,
# promise pipelining) — one kj, no duplicate-symbol conflict.
option (ENABLE_ZAP "Enable ZAP (codec + RPC)" ${ENABLE_LIBRARIES})

if (NOT ENABLE_ZAP)
    message(STATUS "Not using ZAP library")
    return()
endif()

set (ZAP_SOURCE_DIR "${Datastore_SOURCE_DIR}/contrib/zap/c++/src")

# ZAP requires C++23 (uses <print> etc.). The datastore build ships its own libc++,
# which provides the C++23 library; just raise the standard for these targets.
set (CMAKE_CXX_STANDARD 23)

# kj — the toolkit. Includes the async / event-loop / io files needed by zap-rpc
# (the format alone would not need async, but the transport does).
set (KJ_SRCS
    "${ZAP_SOURCE_DIR}/kj/array.c++"
    "${ZAP_SOURCE_DIR}/kj/common.c++"
    "${ZAP_SOURCE_DIR}/kj/debug.c++"
    "${ZAP_SOURCE_DIR}/kj/exception.c++"
    "${ZAP_SOURCE_DIR}/kj/io.c++"
    "${ZAP_SOURCE_DIR}/kj/memory.c++"
    "${ZAP_SOURCE_DIR}/kj/mutex.c++"
    "${ZAP_SOURCE_DIR}/kj/string.c++"
    "${ZAP_SOURCE_DIR}/kj/hash.c++"
    "${ZAP_SOURCE_DIR}/kj/table.c++"
    "${ZAP_SOURCE_DIR}/kj/thread.c++"
    "${ZAP_SOURCE_DIR}/kj/main.c++"
    "${ZAP_SOURCE_DIR}/kj/arena.c++"
    "${ZAP_SOURCE_DIR}/kj/units.c++"
    "${ZAP_SOURCE_DIR}/kj/encoding.c++"
    "${ZAP_SOURCE_DIR}/kj/refcount.c++"
    "${ZAP_SOURCE_DIR}/kj/string-tree.c++"
    "${ZAP_SOURCE_DIR}/kj/source-location.c++"
    "${ZAP_SOURCE_DIR}/kj/list.c++"
    "${ZAP_SOURCE_DIR}/kj/glob-filter.c++"
    "${ZAP_SOURCE_DIR}/kj/cidr.c++"
    "${ZAP_SOURCE_DIR}/kj/time.c++"
    "${ZAP_SOURCE_DIR}/kj/timer.c++"
    "${ZAP_SOURCE_DIR}/kj/filesystem.c++"
    "${ZAP_SOURCE_DIR}/kj/filesystem-disk-unix.c++"
    "${ZAP_SOURCE_DIR}/kj/filesystem-disk-win32.c++"
    "${ZAP_SOURCE_DIR}/kj/parse/char.c++"
    # async / event loop — required by zap-rpc transport
    "${ZAP_SOURCE_DIR}/kj/async.c++"
    "${ZAP_SOURCE_DIR}/kj/async-unix.c++"
    "${ZAP_SOURCE_DIR}/kj/async-io.c++"
    "${ZAP_SOURCE_DIR}/kj/async-io-unix.c++"
)

add_library(_kj ${KJ_SRCS})
target_include_directories(_kj SYSTEM PUBLIC ${ZAP_SOURCE_DIR})

# zap codec — dynamic reflection (used by the CapnProto data format) + the types the
# RPC layer builds on (capability / membrane). Generated *.zap.c++ are the debranded
# *.capnp.c++ schema outputs.
set (ZAP_SRCS
    "${ZAP_SOURCE_DIR}/zap/c++.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/blob.c++"
    "${ZAP_SOURCE_DIR}/zap/arena.c++"
    "${ZAP_SOURCE_DIR}/zap/layout.c++"
    "${ZAP_SOURCE_DIR}/zap/list.c++"
    "${ZAP_SOURCE_DIR}/zap/any.c++"
    "${ZAP_SOURCE_DIR}/zap/message.c++"
    "${ZAP_SOURCE_DIR}/zap/schema.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/stream.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/serialize.c++"
    "${ZAP_SOURCE_DIR}/zap/serialize-packed.c++"
    "${ZAP_SOURCE_DIR}/zap/schema.c++"
    "${ZAP_SOURCE_DIR}/zap/schema-loader.c++"
    "${ZAP_SOURCE_DIR}/zap/dynamic.c++"
    "${ZAP_SOURCE_DIR}/zap/stringify.c++"
    "${ZAP_SOURCE_DIR}/zap/capability.c++"
    "${ZAP_SOURCE_DIR}/zap/dynamic-capability.c++"
    "${ZAP_SOURCE_DIR}/zap/membrane.c++"
)

add_library(_zap ${ZAP_SRCS})
set_target_properties(_zap PROPERTIES LINKER_LANGUAGE CXX)
target_link_libraries(_zap PUBLIC _kj)

# zap-rpc — the native transport: promise pipelining over a two-party connection.
set (ZAP_RPC_SRCS
    "${ZAP_SOURCE_DIR}/zap/serialize-async.c++"
    "${ZAP_SOURCE_DIR}/zap/rpc.c++"
    "${ZAP_SOURCE_DIR}/zap/rpc.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/rpc-twoparty.c++"
    "${ZAP_SOURCE_DIR}/zap/rpc-twoparty.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/persistent.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/reconnect.c++"
)

add_library(_zap_rpc ${ZAP_RPC_SRCS})
target_link_libraries(_zap_rpc PUBLIC _zap)

# zapc — schema parser + compiler front-end (runtime schema parsing for the format).
set (ZAPC_SRCS
    "${ZAP_SOURCE_DIR}/zap/compiler/type-id.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/error-reporter.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/lexer.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/lexer.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/grammar.zap.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/parser.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/generics.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/node-translator.c++"
    "${ZAP_SOURCE_DIR}/zap/compiler/compiler.c++"
    "${ZAP_SOURCE_DIR}/zap/schema-parser.c++"
    "${ZAP_SOURCE_DIR}/zap/serialize-text.c++"
)

add_library(_zapc ${ZAPC_SRCS})
target_link_libraries(_zapc PUBLIC _zap_rpc)

set (ZAP_PRIVATE_CXX_FLAGS -fno-char8_t)
target_compile_options(_kj PRIVATE ${ZAP_PRIVATE_CXX_FLAGS})
target_compile_options(_zap PRIVATE ${ZAP_PRIVATE_CXX_FLAGS})
target_compile_options(_zap_rpc PRIVATE ${ZAP_PRIVATE_CXX_FLAGS})
target_compile_options(_zapc PRIVATE ${ZAP_PRIVATE_CXX_FLAGS})

# _zapc carries the full codec+rpc+schema surface — this is what the native ZAP query
# transport links.
add_library(ch_contrib::zap ALIAS _zapc)

# NOTE: the CapnProto data format (src/Formats/CapnProto*, #if USE_CAPNP) is intentionally
# NOT wired here. It depends on Datastore-fork capnp patches (DynamicStruct/List
# getBuilderImpl/getReaderImpl, Text::Reader->String) that vanilla zap-proto/cpp-core lacks.
# Without a ch_contrib::capnp target, USE_CAPNP=0 and that format gates off cleanly. Re-enabling
# it = porting those ~16 lines of accessors into zap-proto/cpp-core's dynamic.h (tracked follow-up).
