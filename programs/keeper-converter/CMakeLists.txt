set (DATASTORE_KEEPER_CONVERTER_SOURCES KeeperConverter.cpp)

set (DATASTORE_KEEPER_CONVERTER_LINK
    PRIVATE
        boost::program_options
        dbms
)

datastore_program_add(keeper-converter)
