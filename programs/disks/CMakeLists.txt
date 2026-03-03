set (DATASTORE_DISKS_SOURCES
    DisksApp.cpp
    DisksClient.cpp
    ICommand.cpp
    CommandChangeDirectory.cpp
    CommandCopy.cpp
    CommandLink.cpp
    CommandList.cpp
    CommandListDisks.cpp
    CommandMkDir.cpp
    CommandMove.cpp
    CommandRead.cpp
    CommandRemove.cpp
    CommandSwitchDisk.cpp
    CommandWrite.cpp
    CommandHelp.cpp
    CommandTouch.cpp
    CommandGetCurrentDiskAndPath.cpp
    Utils.cpp)

if (DATASTORE_CLOUD)
  set (DATASTORE_DISKS_SOURCES ${DATASTORE_DISKS_SOURCES} CommandPackedIO.cpp)
endif ()

set (DATASTORE_DISKS_LINK
    PRIVATE
        boost::program_options
        datastore_aggregate_functions
        datastore_common_config
        datastore_common_io
        datastore_functions
        datastore_parsers
        datastore_table_functions
        )

datastore_program_add(disks)
