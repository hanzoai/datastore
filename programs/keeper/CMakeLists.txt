set(DATASTORE_KEEPER_SOURCES
    keeper_main.cpp
    Keeper.cpp
)

set (DATASTORE_KEEPER_LINK
    PRIVATE
        datastore_common_config
        datastore_common_io
        datastore_common_zookeeper_base
        datastore_common_zookeeper
        daemon
        clickhouse-keeper-converter-lib
        clickhouse-keeper-client-lib
        datastore_functions
)

# Track dependencies for #embed directives so that changes to embedded files trigger recompilation.
set_source_files_properties(Keeper.cpp PROPERTIES OBJECT_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/keeper_embedded.xml")

datastore_program_add(keeper)

install(FILES keeper_config.xml DESTINATION "${DATASTORE_ETC_DIR}/clickhouse-keeper" COMPONENT clickhouse-keeper)

if (BUILD_STANDALONE_KEEPER)
    # Straight list of all required sources
    datastore_add_executable(clickhouse-keeper ${DATASTORE_KEEPER_SOURCES})
    target_include_directories(clickhouse-keeper PRIVATE .)
    target_link_libraries(clickhouse-keeper PUBLIC ${DATASTORE_KEEPER_LINK})

    set_target_properties(clickhouse-keeper PROPERTIES RUNTIME_OUTPUT_DIRECTORY ../)
    if (SPLIT_DEBUG_SYMBOLS)
        datastore_split_debug_symbols(TARGET clickhouse-keeper DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/../${SPLIT_DEBUG_SYMBOLS_DIR} BINARY_PATH ../clickhouse-keeper)
    else()
        datastore_make_empty_debug_info_for_nfpm(TARGET clickhouse-keeper DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/../${SPLIT_DEBUG_SYMBOLS_DIR})
        install(TARGETS clickhouse-keeper RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT clickhouse)
    endif()

    if (ENABLE_DATASTORE_KEEPER_CLIENT)
        add_custom_command (TARGET clickhouse-keeper POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink clickhouse-keeper clickhouse-keeper-client)
        install (FILES "${CMAKE_CURRENT_BINARY_DIR}/clickhouse-keeper-client" DESTINATION "${CMAKE_INSTALL_BINDIR}" COMPONENT clickhouse-keeper)
    endif()
endif()
