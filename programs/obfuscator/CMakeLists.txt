set (DATASTORE_OBFUSCATOR_SOURCES Obfuscator.cpp)

set (DATASTORE_OBFUSCATOR_LINK
    PRIVATE
        boost::program_options
        dbms
)

datastore_program_add(obfuscator)
