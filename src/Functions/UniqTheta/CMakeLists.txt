include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")

add_library(datastore_functions_uniqtheta FunctionsUniqTheta.cpp)

target_link_libraries(datastore_functions_uniqtheta PRIVATE dbms)

if (TARGET ch_contrib::datasketches)
    target_link_libraries (datastore_functions_uniqtheta PRIVATE ch_contrib::datasketches)
endif ()
