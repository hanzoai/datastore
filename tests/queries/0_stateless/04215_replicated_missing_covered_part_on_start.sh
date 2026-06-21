#!/usr/bin/env bash
# Tags: long, zookeeper, no-shared-merge-tree
# no-shared-merge-tree: depends on local fs

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists rmt1 sync;"
$DATASTORE_CLIENT -q "drop table if exists rmt2 sync;"

zk_path="/test/04215/$DATASTORE_TEST_ZOOKEEPER_PREFIX/$DATASTORE_DATABASE/replicas/1/parts"

$DATASTORE_CLIENT -q "create table rmt1 (n int)
    engine=ReplicatedMergeTree('/test/04215/$DATASTORE_TEST_ZOOKEEPER_PREFIX/{database}', '1')
    order by n
    settings old_parts_lifetime=100500;"

$DATASTORE_CLIENT -q "create table rmt2 (n int)
    engine=ReplicatedMergeTree('/test/04215/$DATASTORE_TEST_ZOOKEEPER_PREFIX/{database}', '2')
    order by n
    settings old_parts_lifetime=100500;"

$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into rmt1 values (1);"
$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into rmt1 values (2);"

$DATASTORE_CLIENT -q "system sync replica rmt1;"
$DATASTORE_CLIENT -q "system sync replica rmt2;"
$DATASTORE_CLIENT -q "system stop merges rmt2;"
$DATASTORE_CLIENT -q "optimize table rmt1 final;"

path=$($DATASTORE_CLIENT -q "select path from system.parts where database='$DATASTORE_DATABASE' and table='rmt1' and name='all_0_1_1'")
$DATASTORE_CLIENT -q "select throwIf(substring('$path', 1, 1) != '/', 'Path is relative: $path') format Null" || exit
rm -rf "$path"

if $DATASTORE_CLIENT -q "select * from rmt1;" >/dev/null 2>&1; then
    echo "Expected read from removed part to fail"
    exit 1
fi

$DATASTORE_CLIENT -q "detach table rmt1 sync;"
$DATASTORE_CLIENT -q "attach table rmt1;"

$DATASTORE_CLIENT --insert_keeper_fault_injection_probability=0 -q "insert into rmt1 values (3);"
$DATASTORE_CLIENT -q "system start merges rmt2;"
$DATASTORE_CLIENT -q "system sync replica rmt1;"
$DATASTORE_CLIENT -q "optimize table rmt1 final;"
$DATASTORE_CLIENT -q "system sync replica rmt1;"

$DATASTORE_CLIENT -q "select throwIf(count() = 0, 'Missing all_0_1_1 in ZooKeeper') from system.zookeeper where path='$zk_path' and name='all_0_1_1' format Null"

$DATASTORE_CLIENT -q "detach table rmt1 sync;"
$DATASTORE_CLIENT -q "attach table rmt1;"

$DATASTORE_CLIENT -q "select count(), sum(n) from rmt1;"

$DATASTORE_CLIENT -q "drop table rmt1 sync;"
$DATASTORE_CLIENT -q "drop table rmt2 sync;"
