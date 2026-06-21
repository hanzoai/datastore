set (DATASTORE_CLIENT_SOURCES
    Client.cpp
    FuzzLoop.cpp
)

set (DATASTORE_CLIENT_LINK
    PRIVATE
        boost::program_options
        clickhouse_aggregate_functions
        clickhouse_common_config
        clickhouse_common_io
        clickhouse_functions
        clickhouse_parsers
)

if (TARGET ch_contrib::jwt-cpp)
    list(APPEND DATASTORE_CLIENT_LINK PUBLIC ch_contrib::jwt-cpp)
endif()

if (ENABLE_BUZZHOUSE)
    list(APPEND DATASTORE_CLIENT_LINK PRIVATE clickhouse_buzzhouse_proto)
endif()

if (TARGET ch_rust::skim)
    list(APPEND DATASTORE_CLIENT_LINK PRIVATE ch_rust::skim)
endif()

# Always use internal readpassphrase
list(APPEND DATASTORE_CLIENT_LINK PRIVATE readpassphrase)

clickhouse_program_add(client)

install (FILES datastore-client.xml DESTINATION "${DATASTORE_ETC_DIR}/datastore-client" COMPONENT datastore-client RENAME config.xml)
