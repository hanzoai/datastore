#!/usr/bin/env bash
# Tags: race, zookeeper, no-object-storage

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_renames0"
$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_renames50"

$DATASTORE_CLIENT --query "CREATE TABLE table_for_renames0 (value UInt64, data String)
ENGINE ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/concurrent_rename', '1') ORDER BY tuple()
SETTINGS cleanup_delay_period = 1, cleanup_delay_period_random_add = 0, cleanup_thread_preferred_points_per_iteration=0"

$DATASTORE_CLIENT --query "INSERT INTO table_for_renames0 SELECT number, toString(number) FROM numbers(1000)"

$DATASTORE_CLIENT --query "INSERT INTO table_for_renames0 SELECT number, toString(number) FROM numbers(1000, 1000)"

$DATASTORE_CLIENT --query "INSERT INTO table_for_renames0 SELECT number, toString(number) FROM numbers(2000, 1000)"

for i in $(seq 1 50); do
    prev_i=$((i - 1))
    $DATASTORE_CLIENT --query "RENAME TABLE table_for_renames$prev_i TO table_for_renames$i"
done

$DATASTORE_CLIENT --query "SELECT COUNT() from table_for_renames50"

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_renames0"
$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_renames50"
