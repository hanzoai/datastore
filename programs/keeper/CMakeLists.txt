set(DATASTORE_KEEPER_SOURCES
    keeper_main.cpp
    Keeper.cpp
)

set (DATASTORE_KEEPER_LINK
    PRIVATE
        clickhouse_common_config
        clickhouse_common_io
        clickhouse_common_zookeeper_base
        clickhouse_common_zookeeper
        daemon
        datastore-keeper-converter-lib
        datastore-keeper-client-lib
        clickhouse_functions
)

# Track dependencies for #embed directives so that changes to embedded files trigger recompilation.
set_source_files_properties(Keeper.cpp PROPERTIES OBJECT_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/keeper_embedded.xml")

clickhouse_program_add(keeper)

install(FILES keeper_config.xml DESTINATION "${DATASTORE_ETC_DIR}/datastore-keeper" COMPONENT datastore-keeper)

if (BUILD_STANDALONE_KEEPER)
    # Straight list of all required sources
    clickhouse_add_executable(datastore-keeper ${DATASTORE_KEEPER_SOURCES})
    target_include_directories(datastore-keeper PRIVATE .)
    target_link_libraries(datastore-keeper PUBLIC ${DATASTORE_KEEPER_LINK})

    set_target_properties(datastore-keeper PROPERTIES RUNTIME_OUTPUT_DIRECTORY ../)
    if (SPLIT_DEBUG_SYMBOLS)
        clickhouse_split_debug_symbols(TARGET datastore-keeper DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/../${SPLIT_DEBUG_SYMBOLS_DIR} BINARY_PATH ../datastore-keeper)
    else()
        clickhouse_make_empty_debug_info_for_nfpm(TARGET datastore-keeper DESTINATION_DIR ${CMAKE_CURRENT_BINARY_DIR}/../${SPLIT_DEBUG_SYMBOLS_DIR})
        install(TARGETS datastore-keeper RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT datastore)
    endif()

    if (ENABLE_DATASTORE_KEEPER_CLIENT)
        add_custom_command (TARGET datastore-keeper POST_BUILD COMMAND ${CMAKE_COMMAND} -E create_symlink datastore-keeper datastore-keeper-client)
        install (FILES "${CMAKE_CURRENT_BINARY_DIR}/datastore-keeper-client" DESTINATION "${CMAKE_INSTALL_BINDIR}" COMPONENT datastore-keeper)
    endif()
endif()
