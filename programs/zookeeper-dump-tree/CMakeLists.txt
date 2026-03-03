set (DATASTORE_ZOOKEEPER_DUMP_TREE_SOURCES ZooKeeperDumpTree.cpp)

set (DATASTORE_ZOOKEEPER_DUMP_TREE_LINK
    PRIVATE
        dbms
        datastore_functions
        boost::program_options
)

datastore_program_add(zookeeper-dump-tree)
