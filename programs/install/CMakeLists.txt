set (DATASTORE_INSTALL_SOURCES Install.cpp)

set (DATASTORE_INSTALL_LINK
    PRIVATE
        boost::program_options
        datastore_common_config
        datastore_common_io
        dbms
        readpassphrase
)

datastore_program_add_library(install)
