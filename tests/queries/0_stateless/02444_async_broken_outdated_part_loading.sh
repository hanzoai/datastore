#!/usr/bin/env bash
# Tags: long, zookeeper, no-shared-merge-tree

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists rmt sync;"
$DATASTORE_CLIENT -q "create table rmt (n int) engine=ReplicatedMergeTree('/test/02444/$DATASTORE_TEST_ZOOKEEPER_PREFIX/rmt', '1') order by n settings old_parts_lifetime=600"

$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into rmt values (1);"
$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into rmt values (2);"

$DATASTORE_CLIENT -q "system sync replica rmt pull;"
$DATASTORE_CLIENT --optimize_throw_if_noop=1 -q "optimize table rmt final"
$DATASTORE_CLIENT -q "system sync replica rmt;"
$DATASTORE_CLIENT -q "select 1, *, _part from rmt order by n;"

path=$($DATASTORE_CLIENT -q "select path from system.parts where database='$DATASTORE_DATABASE' and table='rmt' and name='all_1_1_0'")
# ensure that path is absolute before removing
$DATASTORE_CLIENT -q "select throwIf(substring('$path', 1, 1) != '/', 'Path is relative: $path')" || exit
rm -f "$path/*.bin"

$DATASTORE_CLIENT -q "detach table rmt sync;"
$DATASTORE_CLIENT -q "attach table rmt;"
$DATASTORE_CLIENT -q "select 2, *, _part from rmt order by n;"

$DATASTORE_CLIENT -q "truncate table rmt;"

$DATASTORE_CLIENT -q "detach table rmt sync;"
$DATASTORE_CLIENT -q "attach table rmt;"

$DATASTORE_CLIENT -q "SELECT table, lost_part_count FROM system.replicas WHERE database=currentDatabase() AND lost_part_count!=0";

$DATASTORE_CLIENT -q "drop table rmt sync;"
