set (DATASTORE_SU_SOURCES datastore-su.cpp su.cpp)
set (DATASTORE_SU_LINK PRIVATE dbms)
clickhouse_program_add(su)
