include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")
add_headers_and_sources(datastore_functions_jsonpath Parsers)
add_headers_and_sources(datastore_functions_jsonpath ASTs)
add_headers_and_sources(datastore_functions_jsonpath Generator)
add_library(datastore_functions_jsonpath ${datastore_functions_jsonpath_sources} ${datastore_functions_jsonpath_headers})

target_link_libraries(datastore_functions_jsonpath PRIVATE dbms)
target_link_libraries(datastore_functions_jsonpath PRIVATE datastore_parsers)

if (OMIT_HEAVY_DEBUG_SYMBOLS)
    target_compile_options(datastore_functions_jsonpath PRIVATE "-g1")
endif()
