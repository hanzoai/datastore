set (DATASTORE_EXTRACT_FROM_CONFIG_SOURCES ExtractFromConfig.cpp)

set (DATASTORE_EXTRACT_FROM_CONFIG_LINK
    PRIVATE
        boost::program_options
        datastore_common_config
        datastore_common_io
        datastore_common_zookeeper_base
        datastore_common_zookeeper
)

datastore_program_add(extract-from-config)
