set (DATASTORE_CLIENT_SOURCES
    Client.cpp
    FuzzLoop.cpp
)

set (DATASTORE_CLIENT_LINK
    PRIVATE
        boost::program_options
        datastore_aggregate_functions
        datastore_common_config
        datastore_common_io
        datastore_functions
        datastore_parsers
)

if (TARGET ch_contrib::jwt-cpp)
    list(APPEND DATASTORE_CLIENT_LINK PUBLIC ch_contrib::jwt-cpp)
endif()

if (ENABLE_BUZZHOUSE)
    list(APPEND DATASTORE_CLIENT_LINK PRIVATE datastore_buzzhouse_proto)
endif()

if (TARGET ch_rust::skim)
    list(APPEND DATASTORE_CLIENT_LINK PRIVATE ch_rust::skim)
endif()

# Always use internal readpassphrase
list(APPEND DATASTORE_CLIENT_LINK PRIVATE readpassphrase)

datastore_program_add(client)

install (FILES clickhouse-client.xml DESTINATION "${DATASTORE_ETC_DIR}/clickhouse-client" COMPONENT clickhouse-client RENAME config.xml)
