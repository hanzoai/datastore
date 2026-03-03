include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")

add_headers_and_sources(datastore_functions_gatherutils .)

# Used by arrayResize.cpp
set(DBMS_GATHERUTILS_FUNCTIONS
    createArraySource.cpp
    createValueSource.cpp
    createArraySink.cpp
    resizeConstantSize.cpp
    resizeDynamicSize.cpp
)

extract_into_parent_list(datastore_functions_gatherutils_sources dbms_sources ${DBMS_GATHERUTILS_FUNCTIONS})
extract_into_parent_list(datastore_functions_gatherutils_headers
    GatherUtils.h
)

add_library(datastore_functions_gatherutils ${datastore_functions_gatherutils_sources} ${datastore_functions_gatherutils_headers})
target_link_libraries(datastore_functions_gatherutils PRIVATE dbms)

if (OMIT_HEAVY_DEBUG_SYMBOLS)
    target_compile_options(datastore_functions_gatherutils PRIVATE "-g1")
endif()
