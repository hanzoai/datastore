set (DATASTORE_CHECKSUM_FOR_COMPRESSED_BLOCK_SOURCES ChecksumForCompressedBlock.cpp)

set (DATASTORE_CHECKSUM_FOR_COMPRESSED_BLOCK_LINK
    PRIVATE
        datastore_functions
        dbms
)

datastore_program_add(checksum-for-compressed-block)
