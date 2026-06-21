#!/usr/bin/env bash
# Tags: zookeeper, no-replicated-database, no-shared-merge-tree
# no-replicated-database because it adds extra replicas
# no-shared-merge-tree do something with parts on local fs
# add_minmax_index_for_numeric_columns=0: Adds extra files, which changes the hashes

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists rmt sync;"
$DATASTORE_CLIENT -q "CREATE TABLE rmt (a UInt8, b Int16, c Float32, d String, e Array(UInt8), f Nullable(UUID), g Tuple(UInt8, UInt16))
ENGINE = ReplicatedMergeTree('/test/02253/$DATASTORE_TEST_ZOOKEEPER_PREFIX/rmtt', '1') ORDER BY a PARTITION BY b % 10
SETTINGS old_parts_lifetime = 1, cleanup_delay_period = 0, cleanup_delay_period_random_add = 0, compress_marks=1, compress_primary_key=1,  serialization_info_version = 'basic',
cleanup_thread_preferred_points_per_iteration=0, min_bytes_for_wide_part=0, remove_empty_parts=0, replace_long_file_name_to_hash=0, add_minmax_index_for_numeric_columns=0"

$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "INSERT INTO rmt SELECT rand(1), 0, 1 / rand(3), toString(rand(4)), [rand(5), rand(6)], rand(7) % 2 ? NULL : generateUUIDv4(), (rand(8), rand(9)) FROM numbers(1000);"

$DATASTORE_CLIENT -q "check table rmt settings check_query_single_value_result = 1"
$DATASTORE_CLIENT -q "select count() from rmt"

path=$($DATASTORE_CLIENT -q "select path from system.parts where database='$DATASTORE_DATABASE' and table='rmt' and name='0_0_0_0'")
# ensure that path is absolute before removing
$DATASTORE_CLIENT -q "select throwIf(substring('$path', 1, 1) != '/', 'Path is relative: $path')" || exit
rm -rf "$path"

# detach the broken part, replace it with empty one
$DATASTORE_CLIENT -q "check table rmt settings check_query_single_value_result = 1" 2>/dev/null
$DATASTORE_CLIENT -q "select count() from rmt"

$DATASTORE_CLIENT --receive_timeout=60 -q "system sync replica rmt"

# the empty part should pass the check
$DATASTORE_CLIENT -q "check table rmt settings check_query_single_value_result = 1"
$DATASTORE_CLIENT -q "select count() from rmt"

$DATASTORE_CLIENT -q "select name, part_type, hash_of_all_files, hash_of_uncompressed_files, uncompressed_hash_of_compressed_files from system.parts where database=currentDatabase()"

$DATASTORE_CLIENT -q "drop table rmt sync;"
