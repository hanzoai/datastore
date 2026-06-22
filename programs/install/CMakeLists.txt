set (DATASTORE_INSTALL_SOURCES Install.cpp)

# Track dependencies for #embed directives so that changes to embedded files trigger recompilation.
set_source_files_properties(Install.cpp PROPERTIES OBJECT_DEPENDS
    "${CMAKE_SOURCE_DIR}/programs/server/config.xml;\
${CMAKE_SOURCE_DIR}/programs/server/users.xml")

set (DATASTORE_INSTALL_LINK
    PRIVATE
        boost::program_options
        datastore_common_config
        datastore_common_io
        dbms
        readpassphrase
)

datastore_program_add_library(install)
