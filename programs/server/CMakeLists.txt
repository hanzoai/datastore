set(DATASTORE_SERVER_SOURCES
    MetricsTransmitter.cpp
    Server.cpp
)

set (DATASTORE_SERVER_LINK
    PRIVATE
        datastore_server_zap
        datastore_aggregate_functions
        datastore_common_config
        datastore_common_io
        datastore_common_zookeeper_base
        datastore_common_zookeeper
        datastore_functions
        datastore_parsers
        datastore_storages_system
        datastore_table_functions

    PUBLIC
        daemon
)
if (TARGET ch_contrib::jemalloc)
    list(APPEND DATASTORE_SERVER_LINK PRIVATE ch_contrib::jemalloc)
endif()
if (TARGET ch_contrib::azure_sdk)
    list(APPEND DATASTORE_SERVER_LINK PRIVATE ch_contrib::azure_sdk)
endif()

datastore_program_add(server)

install(FILES config.xml users.xml DESTINATION "${DATASTORE_ETC_DIR}/datastore-server" COMPONENT datastore)

if (ENABLE_FUZZING)
    add_subdirectory(fuzzers)
endif()
