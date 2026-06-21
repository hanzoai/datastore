set (DATASTORE_OBFUSCATOR_SOURCES Obfuscator.cpp)

set (DATASTORE_OBFUSCATOR_LINK
    PRIVATE
        boost::program_options
        dbms
)

clickhouse_program_add(obfuscator)
