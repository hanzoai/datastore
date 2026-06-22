if (NOT TARGET ch_contrib::nuraft)
    message (STATUS "Not building keeper-data-dumper because NuRaft is disabled")
    return ()
endif ()

set (DATASTORE_KEEPER_DATA_DUMPER_SOURCES KeeperDataDumper.cpp)

set (DATASTORE_KEEPER_DATA_DUMPER_LINK
    PRIVATE
        datastore_functions
        dbms
)

datastore_program_add(keeper-data-dumper)
