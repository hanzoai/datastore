# Also in utils

set (DATASTORE_COMPRESSOR_SOURCES Compressor.cpp)

set (DATASTORE_COMPRESSOR_LINK
    PRIVATE
        boost::program_options
        clickhouse_parsers
        dbms
)

clickhouse_program_add(compressor)
