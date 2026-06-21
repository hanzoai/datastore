#!/usr/bin/env bash
# Tags: long, zookeeper, no-shared-merge-tree

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists rmt1 sync;"
$DATASTORE_CLIENT -q "drop table if exists rmt2 sync;"

$DATASTORE_CLIENT -q "create table rmt1 (a int, b int)
    engine = ReplicatedMergeTree('/test/02255/$DATASTORE_TEST_ZOOKEEPER_PREFIX/rmt', 'r1') order by a settings old_parts_lifetime=100500;"

$DATASTORE_CLIENT -q "create table rmt2 (a int, b int)
    engine = ReplicatedMergeTree('/test/02255/$DATASTORE_TEST_ZOOKEEPER_PREFIX/rmt', 'r2') order by a settings old_parts_lifetime=100500;"

$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into rmt1 values (1, 1), (1, 2), (1, 3);"
$DATASTORE_CLIENT -q "alter table rmt1 update b = b*10 where 1 settings mutations_sync=1"
$DATASTORE_CLIENT -q "system sync replica rmt2;"
$DATASTORE_CLIENT -q "select 1, *, _part from rmt2 order by b;"

path=$($DATASTORE_CLIENT -q "select path from system.parts where database='$DATASTORE_DATABASE' and table='rmt1' and name='all_0_0_0'")
# ensure that path is absolute before removing
$DATASTORE_CLIENT -q "select throwIf(substring('$path', 1, 1) != '/', 'Path is relative: $path')" || exit
rm -f "$path/data.bin"

path=$($DATASTORE_CLIENT -q "select path from system.parts where database='$DATASTORE_DATABASE' and table='rmt1' and name='all_0_0_0_1'")
# ensure that path is absolute before removing
$DATASTORE_CLIENT -q "select throwIf(substring('$path', 1, 1) != '/', 'Path is relative: $path')" || exit
rm -f "$path/data.bin"

$DATASTORE_CLIENT -q "detach table rmt1 sync"
$DATASTORE_CLIENT -q "attach table rmt1" 2>/dev/null

$DATASTORE_CLIENT -q "system sync replica rmt1;"
$DATASTORE_CLIENT -q "select 1, *, _part from rmt1 order by b;"

$DATASTORE_CLIENT -q "truncate table rmt1"

$DATASTORE_CLIENT -q "SELECT table, lost_part_count FROM system.replicas WHERE database=currentDatabase() AND lost_part_count!=0";

$DATASTORE_CLIENT -q "drop table if exists projection_broken_parts_1 sync;"
$DATASTORE_CLIENT -q "drop table if exists projection_broken_parts_1 sync;"
