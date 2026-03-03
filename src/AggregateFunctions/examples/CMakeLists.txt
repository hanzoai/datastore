datastore_add_executable (quantile-t-digest quantile-t-digest.cpp)
target_link_libraries (quantile-t-digest PRIVATE dbms datastore_aggregate_functions)

datastore_add_executable (group_array_sorted group_array_sorted.cpp)
target_link_libraries (group_array_sorted PRIVATE dbms datastore_aggregate_functions)
