#!/usr/bin/env bash
# Tags: long, no-random-merge-tree-settings, no-random-settings
# no sanitizers -- bad idea to check memory usage with sanitizers

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

name=test_01655_plan_optimizations_optimize_read_in_window_order_long
max_memory_usage=20000000

$DATASTORE_CLIENT -q "drop table if exists ${name}"
$DATASTORE_CLIENT -q "drop table if exists ${name}_n"
$DATASTORE_CLIENT -q "drop table if exists ${name}_n_x"

$DATASTORE_CLIENT -q "create table ${name} engine=MergeTree order by tuple() as select toInt64((sin(number)+2)*65535)%500 as n, number as x from numbers_mt(5000000)"
$DATASTORE_CLIENT -q "create table ${name}_n engine=MergeTree order by n as select * from ${name} order by n"
$DATASTORE_CLIENT -q "create table ${name}_n_x engine=MergeTree order by (n, x) as select * from ${name} order by n, x"

$DATASTORE_CLIENT -q "optimize table ${name}_n final"
$DATASTORE_CLIENT -q "optimize table ${name}_n_x final"

$DATASTORE_CLIENT --allow_asynchronous_read_from_io_pool_for_merge_tree=0 -q "select n, sum(x) OVER (ORDER BY n, x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n SETTINGS optimize_read_in_order=0, optimize_read_in_window_order=0, max_memory_usage=$max_memory_usage, max_threads=1 format Null" 2>&1 | grep -F -q "MEMORY_LIMIT_EXCEEDED" && echo 'OK' || echo 'FAIL'
$DATASTORE_CLIENT -q "select n, sum(x) OVER (ORDER BY n, x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n SETTINGS optimize_read_in_order=1, optimize_read_in_window_order=1, max_memory_usage=$max_memory_usage, max_threads=1 format Null"

$DATASTORE_CLIENT --allow_asynchronous_read_from_io_pool_for_merge_tree=0 -q "select n, sum(x) OVER (ORDER BY n, x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n_x SETTINGS optimize_read_in_order=0, optimize_read_in_window_order=0, max_memory_usage=$max_memory_usage, max_threads=1 format Null" 2>&1 | grep -F -q "MEMORY_LIMIT_EXCEEDED" && echo 'OK' || echo 'FAIL'
$DATASTORE_CLIENT -q "select n, sum(x) OVER (ORDER BY n, x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n_x SETTINGS optimize_read_in_order=1, optimize_read_in_window_order=1, max_memory_usage=$max_memory_usage, max_threads=1 format Null"

$DATASTORE_CLIENT --allow_asynchronous_read_from_io_pool_for_merge_tree=0 -q "select n, sum(x) OVER (PARTITION BY n ORDER BY x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n_x SETTINGS optimize_read_in_order=0, optimize_read_in_window_order=0, max_memory_usage=$max_memory_usage, max_threads=1 format Null" 2>&1 | grep -F -q "MEMORY_LIMIT_EXCEEDED" && echo 'OK' || echo 'FAIL'
$DATASTORE_CLIENT -q "select n, sum(x) OVER (PARTITION BY n ORDER BY x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n_x SETTINGS optimize_read_in_order=1, optimize_read_in_window_order=1, max_memory_usage=$max_memory_usage, max_threads=1 format Null"

$DATASTORE_CLIENT --allow_asynchronous_read_from_io_pool_for_merge_tree=0 -q "select n, sum(x) OVER (PARTITION BY n+x%2 ORDER BY n, x ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) from ${name}_n_x SETTINGS optimize_read_in_order=1, max_memory_usage=$max_memory_usage, max_threads=1 format Null" 2>&1 | grep -F -q "MEMORY_LIMIT_EXCEEDED" && echo 'OK' || echo 'FAIL'

$DATASTORE_CLIENT -q "drop table ${name}"
$DATASTORE_CLIENT -q "drop table ${name}_n"
$DATASTORE_CLIENT -q "drop table ${name}_n_x"
