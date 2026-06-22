include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")

add_headers_and_sources(datastore_common_access .)
add_library(datastore_common_access ${datastore_common_access_headers} ${datastore_common_access_sources})
target_link_libraries(datastore_common_access PUBLIC datastore_common_io)

if (TARGET ch_contrib::libcotp)
    target_link_libraries (datastore_common_access PRIVATE ch_contrib::libcotp)
endif()
