if (NOT TARGET ch_contrib::rapidjson OR NOT TARGET ch_contrib::nuraft)
    message (STATUS "Not building keeper-bench because RapidJSON or NuRaft is disabled")
    return()
endif ()

set (DATASTORE_KEEPER_BENCH_SOURCES
    Generator.cpp
    Runner.cpp
    Stats.cpp
    KeeperBench.cpp
)

set (DATASTORE_KEEPER_BENCH_LINK
    PRIVATE
        dbms
        datastore_functions
        ch_contrib::rapidjson
)

datastore_program_add(keeper-bench)
