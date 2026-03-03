include("${Datastore_SOURCE_DIR}/cmake/dbms_glob_sources.cmake")
add_headers_and_sources(datastore_aggregate_functions .)
add_headers_and_sources(datastore_aggregate_functions Combinators)
add_headers_and_sources(datastore_aggregate_functions TimeSeries)

extract_into_parent_list(datastore_aggregate_functions_sources dbms_sources
    AggregateFunctionFactory.cpp # AggregateFunctionFactory::instance() Used many times
    Combinators/AggregateFunctionCombinatorFactory.cpp # AggregateFunctionCombinatorFactory::instance() Used by AggregateFunctionFactory.cpp
    AggregateFunctionCount.cpp # Used in optimizeUseAggregateProjection.cpp
    IAggregateFunction.cpp # For AggregateFunctionCount.cpp, WindowTransform.cpp, FunctionsConversion.cpp...
    parseAggregateFunctionParameters.cpp # getAggregateFunctionNameAndParametersArray, getAggregateFunctionParametersArray (Graphite.cpp, ExpressionAnalyzer.cpp)
)
extract_into_parent_list(datastore_aggregate_functions_headers dbms_headers
    IAggregateFunction.h
    Combinators/IAggregateFunctionCombinator.h
    AggregateFunctionFactory.h
    Combinators/AggregateFunctionCombinatorFactory.h
    FactoryHelpers.h
    parseAggregateFunctionParameters.h
)

add_library(datastore_aggregate_functions ${datastore_aggregate_functions_headers} ${datastore_aggregate_functions_sources})
target_link_libraries(datastore_aggregate_functions PRIVATE dbms PUBLIC ch_contrib::cityhash)

if(ENABLE_EXAMPLES)
    add_subdirectory(examples)
endif()

if (ENABLE_FUZZING)
    add_subdirectory(fuzzers)
endif()
