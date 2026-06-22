add_library (daemon
    BaseDaemon.cpp
    GraphiteWriter.cpp
    CrashWriter.cpp
)

target_link_libraries (daemon PUBLIC loggers common PRIVATE datastore_parsers datastore_common_io datastore_common_config)
