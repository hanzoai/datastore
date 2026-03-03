datastore_add_executable(zkutil_test_commands zkutil_test_commands.cpp)
target_link_libraries(zkutil_test_commands PRIVATE
    datastore_common_zookeeper_base datastore_common_zookeeper_no_log
    dbms)

datastore_add_executable(zkutil_test_commands_new_lib zkutil_test_commands_new_lib.cpp)
target_link_libraries(zkutil_test_commands_new_lib PRIVATE
    datastore_common_zookeeper_base datastore_common_zookeeper_no_log
    datastore_compression
    dbms)

datastore_add_executable(zkutil_test_async zkutil_test_async.cpp)
target_link_libraries(zkutil_test_async PRIVATE
    datastore_common_zookeeper_base datastore_common_zookeeper_no_log
    dbms)
