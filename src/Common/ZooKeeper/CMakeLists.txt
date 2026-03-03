include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")

add_headers_and_sources(datastore_common_zookeeper .)
add_headers_and_sources(datastore_common_zookeeper KeeperClientCLI)

# Needs to be built differently depending on ZOOKEEPER_LOG
list(REMOVE_ITEM datastore_common_zookeeper_sources "ZooKeeperImpl.cpp")


add_library(datastore_common_zookeeper_base ${datastore_common_zookeeper_headers} ${datastore_common_zookeeper_sources})
target_link_libraries (datastore_common_zookeeper_base
    PUBLIC
        datastore_common_io
        datastore_compression
        common
)

# for datastore server
add_library(datastore_common_zookeeper ZooKeeperImpl.cpp)
target_compile_definitions (datastore_common_zookeeper PRIVATE -DZOOKEEPER_LOG)
target_link_libraries (datastore_common_zookeeper
    PUBLIC
        datastore_common_zookeeper_base
        datastore_common_io
        datastore_compression
        common
)

# for examples -- no logging (to avoid extra dependencies)
add_library(datastore_common_zookeeper_no_log ZooKeeperImpl.cpp)
target_link_libraries (datastore_common_zookeeper_no_log
    PUBLIC
        datastore_common_io
        datastore_compression
        common
)
if (ENABLE_EXAMPLES)
    add_subdirectory(examples)
endif()
