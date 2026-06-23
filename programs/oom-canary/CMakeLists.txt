set (DATASTORE_OOM_CANARY_SOURCES datastore-oom-canary.cpp OomCanary.cpp)
set (DATASTORE_OOM_CANARY_LINK PRIVATE dbms)
datastore_program_add(oom-canary)
