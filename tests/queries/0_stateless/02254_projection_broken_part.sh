#!/usr/bin/env bash
# Tags: long, zookeeper, no-shared-merge-tree

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists projection_broken_parts_1 sync;"
$DATASTORE_CLIENT -q "drop table if exists projection_broken_parts_1 sync;"

$DATASTORE_CLIENT -q "create table projection_broken_parts_1 (a int, b int, projection ab (select a, sum(b) group by a))
    engine = ReplicatedMergeTree('/test/02254/$DATASTORE_TEST_ZOOKEEPER_PREFIX/rmt', 'r1')
    order by a settings index_granularity = 1;"

$DATASTORE_CLIENT -q "create table projection_broken_parts_2 (a int, b int, projection ab (select a, sum(b) group by a))
    engine = ReplicatedMergeTree('/test/02254/$DATASTORE_TEST_ZOOKEEPER_PREFIX/rmt', 'r2')
    order by a settings index_granularity = 1;"

$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into projection_broken_parts_1 values (1, 1), (1, 2), (1, 3);"
$DATASTORE_CLIENT -q "system sync replica projection_broken_parts_2;"
$DATASTORE_CLIENT -q "select 1, *, _part from projection_broken_parts_2 order by b;"
$DATASTORE_CLIENT -q "select 2, sum(b) from projection_broken_parts_2 group by a;"

path=$($DATASTORE_CLIENT -q "select path from system.parts where database='$DATASTORE_DATABASE' and table='projection_broken_parts_1' and name='all_0_0_0'")
# ensure that path is absolute before removing
$DATASTORE_CLIENT -q "select throwIf(substring('$path', 1, 1) != '/', 'Path is relative: $path')" || exit
rm -f "$path/ab.proj/data.bin"

$DATASTORE_CLIENT -q "select 3, sum(b) from projection_broken_parts_1 group by a format Null;" 2>/dev/null

num_tries=0
while ! $DATASTORE_CLIENT -q "select 4, sum(b) from projection_broken_parts_1 group by a format Null;" 2>/dev/null; do
    sleep 1;
    num_tries=$((num_tries+1))
    if [ $num_tries -eq 60 ]; then
        break
    fi
done

$DATASTORE_CLIENT -q "system sync replica projection_broken_parts_1;"
$DATASTORE_CLIENT -q "select 5, sum(b) from projection_broken_parts_1 group by a;"

$DATASTORE_CLIENT -q "drop table if exists projection_broken_parts_1 sync;"
$DATASTORE_CLIENT -q "drop table if exists projection_broken_parts_1 sync;"
