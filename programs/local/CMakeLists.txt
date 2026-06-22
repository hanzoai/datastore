set (DATASTORE_LOCAL_SOURCES LocalServer.cpp)

set (DATASTORE_LOCAL_LINK
    PRIVATE
        boost::program_options
        datastore_aggregate_functions
        datastore_common_config
        datastore_common_io
        datastore_functions
        datastore_parsers
        datastore_storages_system
        datastore_table_functions
)

datastore_program_add(local)

target_link_libraries(clickhouse-local-lib PRIVATE clickhouse-server-lib)

if (TARGET ch_rust::skim)
    target_link_libraries(clickhouse-local-lib PRIVATE ch_rust::skim)
endif()
if (TARGET ch_contrib::azure_sdk)
    target_link_libraries(clickhouse-local-lib PRIVATE ch_contrib::azure_sdk)
endif()

# Always use internal readpassphrase
target_link_libraries(clickhouse-local-lib PRIVATE readpassphrase)

if (ENABLE_FUZZING)
    add_subdirectory(fuzzers)
endif()
