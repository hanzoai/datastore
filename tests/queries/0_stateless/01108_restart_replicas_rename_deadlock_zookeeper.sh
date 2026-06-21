#!/usr/bin/env bash
# Tags: deadlock, replica

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

for i in $(seq 4); do
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS replica_01108_$i"
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS replica_01108_${i}_tmp"
    $DATASTORE_CLIENT -q "CREATE TABLE replica_01108_$i (n int) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/replica_01108_$i', 'replica') ORDER BY tuple()"
    $DATASTORE_CLIENT -q "INSERT INTO replica_01108_$i SELECT * FROM system.numbers LIMIT $i * 10, 10"
done

function rename_thread_1()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]; do
        $DATASTORE_CLIENT -q "RENAME TABLE replica_01108_1 TO replica_01108_1_tmp,
                                            replica_01108_2 TO replica_01108_2_tmp,
                                            replica_01108_3 TO replica_01108_3_tmp,
                                            replica_01108_4 TO replica_01108_4_tmp"
        sleep 0.$RANDOM
    done |& grep LOGICAL_ERROR
}

function rename_thread_2()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]; do
        $DATASTORE_CLIENT -q "RENAME TABLE replica_01108_1_tmp TO replica_01108_2,
                                            replica_01108_2_tmp TO replica_01108_3,
                                            replica_01108_3_tmp TO replica_01108_4,
                                            replica_01108_4_tmp TO replica_01108_1"
        sleep 0.$RANDOM
    done |& grep LOGICAL_ERROR
}

function restart_replicas_loop()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]; do
        for i in $(seq 4); do
            $DATASTORE_CLIENT -q "SYSTEM RESTART REPLICA replica_01108_${i}"
            $DATASTORE_CLIENT -q "SYSTEM RESTART REPLICA replica_01108_${i}_tmp"
        done
        sleep 0.$RANDOM
    done |& grep LOGICAL_ERROR
}

TIMEOUT=10

rename_thread_1 &
rename_thread_2 &
restart_replicas_loop &

wait

for i in $(seq 4); do
    $DATASTORE_CLIENT -q "SYSTEM SYNC REPLICA replica_01108_$i" >/dev/null 2>&1
    $DATASTORE_CLIENT -q "SYSTEM SYNC REPLICA replica_01108_${i}_tmp" >/dev/null 2>&1
done

while [[ $($DATASTORE_CLIENT -q "SELECT count() FROM system.processes WHERE current_database = currentDatabase() AND query LIKE 'RENAME%'") -gt 0 ]]; do
    sleep 1
done

$DATASTORE_CLIENT -q "SELECT replaceOne(name, '_tmp', '') FROM system.tables WHERE database = '$DATASTORE_DATABASE' AND match(name, '^replica_01108_')"
$DATASTORE_CLIENT -q "SELECT sum(n), count(n) FROM merge('$DATASTORE_DATABASE', '^replica_01108_') GROUP BY position(_table, 'tmp')"


for i in $(seq 4); do
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS replica_01108_$i"
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS replica_01108_${i}_tmp"
done
