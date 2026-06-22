include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")
add_headers_and_sources(datastore_functions_kusto .)
add_library(datastore_functions_kusto OBJECT ${datastore_functions_kusto_sources} ${datastore_functions_kusto_headers})
target_link_libraries(datastore_functions_kusto PRIVATE dbms datastore_functions_gatherutils)

if (OMIT_HEAVY_DEBUG_SYMBOLS)
    target_compile_options(datastore_functions_kusto PRIVATE "-g1")
endif()
