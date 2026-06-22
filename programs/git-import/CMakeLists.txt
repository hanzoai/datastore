set (DATASTORE_GIT_IMPORT_SOURCES git-import.cpp)

set (DATASTORE_GIT_IMPORT_LINK
    PRIVATE
        boost::program_options
        dbms
)

datastore_program_add(git-import)

