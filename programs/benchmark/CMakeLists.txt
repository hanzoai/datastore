set (DATASTORE_BENCHMARK_SOURCES Benchmark.cpp)

set (DATASTORE_BENCHMARK_LINK
    PRIVATE
        boost::program_options
        datastore_aggregate_functions
        datastore_common_config
        dbms
)

datastore_program_add(benchmark)

target_link_libraries (clickhouse-benchmark-lib PRIVATE clickhouse-client-lib)
