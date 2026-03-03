include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")

add_headers_and_sources(datastore_table_functions .)

if (TARGET ch_contrib::hivemetastore)
    add_headers_and_sources(datastore_table_functions Hive)
endif ()

# TableFunctionFactory::instance(), TableFunctionFactory::get(), DB::ITableFunction::execute(), TableFunctionView::getSelectQuery()
# Used by different storages and analyzer
extract_into_parent_list(datastore_table_functions_sources dbms_sources
    ITableFunction.cpp
    TableFunctionView.cpp
    TableFunctionFactory.cpp
)
extract_into_parent_list(datastore_table_functions_headers dbms_headers
    ITableFunction.h
    TableFunctionView.h
    TableFunctionFactory.h
)

add_library(datastore_table_functions ${datastore_table_functions_headers} ${datastore_table_functions_sources})

target_link_libraries(datastore_table_functions PRIVATE datastore_parsers datastore_storages_system dbms)

if (TARGET ch_contrib::hivemetastore)
    target_link_libraries(datastore_table_functions PRIVATE ch_contrib::hivemetastore ch_contrib::hdfs ch_contrib::parquet)
endif ()

if (TARGET ch_contrib::azure_sdk)
    target_link_libraries(datastore_table_functions PRIVATE ch_contrib::azure_sdk)
endif ()

if (TARGET ch_contrib::simdjson)
    target_link_libraries(datastore_table_functions PRIVATE ch_contrib::simdjson)
endif ()

if (TARGET ch_contrib::rapidjson)
    target_link_libraries(datastore_table_functions PRIVATE ch_contrib::rapidjson)
endif ()
