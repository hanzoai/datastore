add_compile_options("$<$<OR:$<COMPILE_LANGUAGE:C>,$<COMPILE_LANGUAGE:CXX>>:${COVERAGE_FLAGS}>")

if (USE_CLANG_TIDY)
    set (CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_PATH}")
endif ()

include(${Datastore_SOURCE_DIR}/cmake/split_debug_symbols.cmake)

# The `datastore` binary is a multi purpose tool that contains multiple execution modes (client, server, etc.),
# So client/server/... is just a symlink to `datastore` binary.
#
# But, there are several components that requires extra libraries, like keeper
# requires NuRaft, that regular binary does not requires, so you can disable
# compilation of this components.
#
# If you do not know what modes you need, turn then all.
option (ENABLE_DATASTORE_ALL "Enable all Datastore modes by default" ON)

# https://presentations.datastore.com/matemarketing_2020/
option (ENABLE_DATASTORE_GIT_IMPORT "A tool to analyze Git repositories" ${ENABLE_DATASTORE_ALL})

option (ENABLE_DATASTORE_KEEPER "Datastore alternative to ZooKeeper (standalone keeper entry-point bound into the multipurpose binary)" OFF)

option (ENABLE_DATASTORE_KEEPER_CONVERTER "Util allows to convert ZooKeeper logs and snapshots into datastore-keeper snapshot" OFF)

option (ENABLE_DATASTORE_KEEPER_CLIENT "Datastore Keeper Client" OFF)

# NOTE: Embedded coordination (Raft via NuRaft) is provided by `src/Coordination/` and is
# linked into the server library unconditionally. Setting the options above to OFF only
# drops the standalone keeper entry-point and the keeper-converter/keeper-client tools;
# `MergeTree` replication and DDL coordination via `<keeper_server>` config still work.

if (NOT ENABLE_NURAFT)
    # RECONFIGURE_MESSAGE_LEVEL should not be used here,
    # since ENABLE_NURAFT is set to OFF for FreeBSD and Darwin.
    message (STATUS "datastore-keeper and datastore-keeper-converter will not be built (lack of NuRaft)")
    set(ENABLE_DATASTORE_KEEPER OFF)
    set(ENABLE_DATASTORE_KEEPER_CONVERTER OFF)
endif()

message(STATUS "Datastore extra components:")

if (ENABLE_DATASTORE_SELF_EXTRACTING)
    message(STATUS "Self-extracting executable: ON")
else()
    message(STATUS "Self-extracting executable: OFF")
endif()

if (ENABLE_DATASTORE_KEEPER_CONVERTER)
    message(STATUS "Datastore keeper-converter mode: ON")
else()
    message(STATUS "Datastore keeper-converter mode: OFF")
endif()

if (ENABLE_DATASTORE_KEEPER)
    message(STATUS "Datastore Keeper: ON")
else()
    message(STATUS "Datastore Keeper: OFF")
endif()

if (ENABLE_DATASTORE_KEEPER_CLIENT)
    message(STATUS "Datastore keeper-client mode: ON")
else()
    message(STATUS "Datastore keeper-client mode: OFF")
endif()

configure_file (config_tools.h.in ${CONFIG_INCLUDE_PATH}/config_tools.h)

macro(datastore_target_link_split_lib target name)
    target_link_libraries(${target} PRIVATE datastore-${name}-lib)
endmacro()

macro(datastore_program_add_library name)
    string(TOUPPER ${name} name_uc)
    string(REPLACE "-" "_" name_uc ${name_uc})

    # Some dark magic
    set(DATASTORE_${name_uc}_SOURCES ${DATASTORE_${name_uc}_SOURCES} PARENT_SCOPE)
    set(DATASTORE_${name_uc}_LINK ${DATASTORE_${name_uc}_LINK} PARENT_SCOPE)
    set(DATASTORE_${name_uc}_INCLUDE ${DATASTORE_${name_uc}_INCLUDE} PARENT_SCOPE)

    add_library(datastore-${name}-lib ${DATASTORE_${name_uc}_SOURCES})

    set(_link ${DATASTORE_${name_uc}_LINK}) # can't use ${} in if()
    if(_link)
        target_link_libraries(datastore-${name}-lib PRIVATE ${DATASTORE_${name_uc}_LINK})
    endif()

    target_include_directories (datastore-${name}-lib PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    set(_include ${DATASTORE_${name_uc}_INCLUDE}) # can't use ${} in if()
    if (_include)
        target_include_directories(datastore-${name}-lib ${DATASTORE_${name_uc}_INCLUDE})
    endif()
endmacro()

macro(datastore_program_add name)
    datastore_program_add_library(${name})
endmacro()

add_subdirectory (bash-completion)
add_subdirectory (benchmark)
add_subdirectory (check-marks)
add_subdirectory (checksum-for-compressed-block)
add_subdirectory (client)
add_subdirectory (compressor)
add_subdirectory (disks)
add_subdirectory (extract-from-config)
add_subdirectory (format)
add_subdirectory (git-import)
add_subdirectory (install)
add_subdirectory (keeper-bench)
add_subdirectory (keeper-data-dumper)
add_subdirectory (keeper-utils)
add_subdirectory (local)
add_subdirectory (obfuscator)
add_subdirectory (server)
add_subdirectory (static-files-disk-uploader)
add_subdirectory (su)
add_subdirectory (zookeeper-dump-tree)
add_subdirectory (zookeeper-remove-by-list)
if (ENABLE_DATASTORE_KEEPER_CONVERTER)
    add_subdirectory (keeper-converter)
endif()

if (ENABLE_DATASTORE_KEEPER_CLIENT)
    add_subdirectory (keeper-client)
endif()

if (ENABLE_DATASTORE_KEEPER)
    add_subdirectory (keeper)
endif()

if (ENABLE_DATASTORE_SELF_EXTRACTING AND NOT ENABLE_DUMMY_LAUNCHERS)
    add_subdirectory (self-extracting)
endif ()

datastore_add_executable (datastore main.cpp)

# A library that prevent usage of several functions from libc.
if (ARCH_AMD64 AND OS_LINUX AND NOT OS_ANDROID)
    set (HARMFUL_LIB harmful)
endif ()

target_link_libraries (datastore PRIVATE datastore_common_io ${HARMFUL_LIB})
target_include_directories (datastore PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

if (ENABLE_DATASTORE_KEEPER)
    datastore_target_link_split_lib(datastore keeper)
endif()
if (ENABLE_DATASTORE_KEEPER_CONVERTER)
    datastore_target_link_split_lib(datastore keeper-converter)
endif()
if (ENABLE_DATASTORE_KEEPER_CLIENT)
    datastore_target_link_split_lib(datastore keeper-client)
endif()
datastore_target_link_split_lib(datastore install)

macro(datastore_program_alias alias)
    message(STATUS "Adding alias ${alias}")
    add_custom_command (TARGET datastore POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink datastore ${alias})
    install (FILES "${CMAKE_CURRENT_BINARY_DIR}/${alias}" DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)
endmacro()

set (DATASTORE_BUNDLE)
function(datastore_program_install name lib_name)
    datastore_target_link_split_lib(datastore ${lib_name})
    add_custom_command (TARGET datastore POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink datastore ${name})
    install (FILES "${CMAKE_CURRENT_BINARY_DIR}/${name}" DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)

    foreach(alias ${ARGN})
        datastore_program_alias(${alias})
    endforeach()
endfunction()

if (ENABLE_DATASTORE_SELF_EXTRACTING)
    list(APPEND DATASTORE_BUNDLE self-extracting)
endif ()

datastore_program_install(datastore-benchmark benchmark)
datastore_program_install(datastore-check-marks check-marks)
datastore_program_install(datastore-checksum-for-compressed-block checksum-for-compressed-block)
datastore_program_install(datastore-client client chc)
datastore_program_install(datastore-compressor compressor)
datastore_program_install(datastore-disks disks)
datastore_program_install(datastore-extract-from-config extract-from-config)
datastore_program_install(datastore-format format)
datastore_program_install(datastore-git-import git-import)
datastore_program_install(datastore-local local chl ch)
datastore_program_install(datastore-obfuscator obfuscator)
datastore_program_install(datastore-server server)
datastore_program_install(datastore-static-files-disk-uploader static-files-disk-uploader)
datastore_program_install(datastore-su su)
datastore_program_install(datastore-zookeeper-dump-tree zookeeper-dump-tree)
datastore_program_install(datastore-zookeeper-remove-by-list zookeeper-remove-by-list)

if (TARGET ch_contrib::nuraft)
    datastore_program_install(datastore-keeper-data-dumper keeper-data-dumper)
    datastore_program_install(datastore-keeper-utils keeper-utils)
endif ()

if (TARGET ch_contrib::rapidjson AND TARGET ch_contrib::nuraft)
    datastore_program_install(datastore-keeper-bench keeper-bench)
endif ()

if (ENABLE_DATASTORE_KEEPER)
    if (NOT BUILD_STANDALONE_KEEPER)
        add_custom_command (TARGET datastore POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink datastore datastore-keeper)
        install (FILES "${CMAKE_CURRENT_BINARY_DIR}/datastore-keeper" DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)
        datastore_make_empty_debug_info_for_nfpm(TARGET datastore BINARY datastore-keeper DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/../${SPLIT_DEBUG_SYMBOLS_DIR})
    endif()

    # otherwise we don't build keeper
    if (BUILD_STANDALONE_KEEPER)
        list(APPEND DATASTORE_BUNDLE datastore-keeper)
    endif()
endif ()
if (ENABLE_DATASTORE_KEEPER_CONVERTER)
    add_custom_command (TARGET datastore POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink datastore datastore-keeper-converter)
    install (FILES "${CMAKE_CURRENT_BINARY_DIR}/datastore-keeper-converter" DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)
endif ()
if (ENABLE_DATASTORE_KEEPER_CLIENT)
    if (NOT BUILD_STANDALONE_KEEPER)
        add_custom_command (TARGET datastore POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink datastore datastore-keeper-client)
        install (FILES "${CMAKE_CURRENT_BINARY_DIR}/datastore-keeper-client" DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)
    endif ()
endif ()

add_custom_target (datastore-bundle ALL DEPENDS ${DATASTORE_BUNDLE})

if (USE_BINARY_HASH)
    add_dependencies(datastore hash-binary)

    # When cross-compiling, use the native-built hash-binary; otherwise use the regular build output
    if (CMAKE_CROSSCOMPILING)
        set(HASH_BINARY_PATH "${PROJECT_BINARY_DIR}/native/utils/hash-binary/hash-binary")
    else()
        set(HASH_BINARY_PATH "$<TARGET_FILE:hash-binary>")
    endif()

    add_custom_command(TARGET datastore POST_BUILD
        COMMAND ${HASH_BINARY_PATH} datastore > hash 2> /dev/null
        COMMENT "Computing hash of datastore binary" VERBATIM)

    if (NOT CMAKE_CROSSCOMPILING)
        add_custom_command(TARGET datastore POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "Verifying hash-binary utility matches datastore hash-binary..."
            COMMAND sh -c "./datastore hash-binary > hash.verify && diff -u hash hash.verify || (echo 'ERROR: hash-binary utility output does not match datastore hash-binary' && exit 1)"
            COMMAND ${CMAKE_COMMAND} -E rm hash.verify
            COMMENT "Verifying hash-binary output matches datastore hash-binary" VERBATIM)
    endif()

    add_custom_command(TARGET datastore POST_BUILD
        COMMAND ${OBJCOPY_PATH} --add-section .datastore.hash=hash datastore
        COMMENT "Adding section '.datastore.hash' to datastore binary" VERBATIM)
endif()

if (CHECK_LARGE_OBJECT_SIZES)
    add_custom_command(TARGET datastore POST_BUILD
        COMMAND "${CMAKE_SOURCE_DIR}/utils/check-large-objects.sh" "${CMAKE_BINARY_DIR}")
endif ()

if (SPLIT_DEBUG_SYMBOLS)
    datastore_split_debug_symbols(TARGET datastore DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/${SPLIT_DEBUG_SYMBOLS_DIR} BINARY_PATH datastore)
else()
    datastore_make_empty_debug_info_for_nfpm(TARGET datastore BINARY datastore DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/${SPLIT_DEBUG_SYMBOLS_DIR})
    install (TARGETS datastore RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)
endif()

if (BUILD_STRIPPED_BINARY)
    add_custom_target(datastore-stripped ALL
        COMMAND "${STRIP_PATH}" -o "${CMAKE_CURRENT_BINARY_DIR}/datastore-stripped" --strip-debug --remove-section=.comment --remove-section=.note "${CMAKE_CURRENT_BINARY_DIR}/datastore"
        DEPENDS datastore
        COMMENT "Stripping datastore binary" VERBATIM)
endif()

if (ENABLE_TESTS)
    set (DATASTORE_UNIT_TESTS_TARGETS unit_tests_dbms)
    add_custom_target (datastore-tests ALL DEPENDS ${DATASTORE_UNIT_TESTS_TARGETS})
    add_dependencies(datastore-bundle datastore-tests)
endif()

if (TARGET ch_contrib::protobuf)
    get_property(google_proto_files TARGET ch_contrib::protobuf PROPERTY google_proto_files)
    foreach (proto_file IN LISTS google_proto_files)
        install(FILES ${proto_file} DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/datastore/protos/google/protobuf)
    endforeach()
endif ()

# FIXME: This should be at the end, to avoid using symbols from chdig if there
# are the same in one of contribs (the problem was with lz4)
if (TARGET ch_rust::chdig)
    target_link_libraries (datastore PRIVATE ch_rust::chdig)

    datastore_program_alias(datastore-chdig)
    datastore_program_alias(chdig)
else()
    message(STATUS "Adding dummy chdig targets (for nfpm)")
    foreach (chdig_path ${CMAKE_BINARY_DIR}/chdig ${CMAKE_BINARY_DIR}/datastore-chdig)
        file(GENERATE OUTPUT ${chdig_path} CONTENT "#!/usr/bin/env sh\necho chdig is not enabled in this Datastore build >&2 && exit 1\n")
        install(FILES ${chdig_path}
            DESTINATION ${CMAKE_INSTALL_BINDIR}
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                        GROUP_READ GROUP_EXECUTE
                        WORLD_READ WORLD_EXECUTE
        )
    endforeach()
endif ()
