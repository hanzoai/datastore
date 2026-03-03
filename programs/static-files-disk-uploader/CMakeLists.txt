set (DATASTORE_STATIC_FILES_DISK_UPLOADER_SOURCES static-files-disk-uploader.cpp)

set (DATASTORE_STATIC_FILES_DISK_UPLOADER_LINK
    PRIVATE
        boost::program_options
        dbms
)

datastore_program_add(static-files-disk-uploader)
