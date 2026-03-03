# Also in utils

set (DATASTORE_COMPRESSOR_SOURCES Compressor.cpp)

set (DATASTORE_COMPRESSOR_LINK
    PRIVATE
        boost::program_options
        datastore_parsers
        dbms
)

datastore_program_add(compressor)
