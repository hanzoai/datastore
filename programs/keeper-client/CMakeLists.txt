set (DATASTORE_KEEPER_CLIENT_SOURCES KeeperClient.cpp)

set (DATASTORE_KEEPER_CLIENT_LINK
    PRIVATE
    boost::program_options
    dbms
)

datastore_program_add(keeper-client)
