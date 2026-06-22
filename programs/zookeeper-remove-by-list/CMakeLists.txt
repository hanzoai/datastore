set (DATASTORE_ZOOKEEPER_REMOVE_BY_LIST_SOURCES ZooKeeperRemoveByList.cpp)

set (DATASTORE_ZOOKEEPER_REMOVE_BY_LIST_LINK
    PRIVATE
        dbms
        datastore_functions
        boost::program_options
)

datastore_program_add(zookeeper-remove-by-list)
