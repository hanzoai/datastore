set (DATASTORE_FORMAT_SOURCES Format.cpp)

set (DATASTORE_FORMAT_LINK
    PRIVATE
        boost::program_options
        datastore_common_io
        datastore_parsers
        datastore_functions
        datastore_aggregate_functions
        datastore_table_functions
)

datastore_program_add(format)
