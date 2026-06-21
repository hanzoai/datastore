#!/usr/bin/env bash
# Tags: long, no-msan
# no-msan: too slow, concurrent ALTER operations with 500 columns can cause timeout

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "DROP TABLE IF EXISTS concurrent_alter_column" | ${DATASTORE_CLIENT}
echo "CREATE TABLE concurrent_alter_column (ts DATETIME) ENGINE = MergeTree PARTITION BY toStartOfDay(ts) ORDER BY tuple() SETTINGS auto_statistics_types = ''" | ${DATASTORE_CLIENT}

function thread1()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        for i in {1..500}; do echo "ALTER TABLE concurrent_alter_column ADD COLUMN c$i DOUBLE;"; done | ${DATASTORE_CLIENT} -n --query_id=alter_00816_1
    done
}

function thread2()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        echo "ALTER TABLE concurrent_alter_column ADD COLUMN d DOUBLE" | ${DATASTORE_CLIENT} --query_id=alter_00816_2;
        sleep "$(echo 0.0$RANDOM)";
        echo "ALTER TABLE concurrent_alter_column DROP COLUMN d" | ${DATASTORE_CLIENT} --query_id=alter_00816_2;
    done
}

function thread3()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        echo "ALTER TABLE concurrent_alter_column ADD COLUMN e DOUBLE" | ${DATASTORE_CLIENT} --query_id=alter_00816_3;
        sleep "$(echo 0.0$RANDOM)";
        echo "ALTER TABLE concurrent_alter_column DROP COLUMN e" | ${DATASTORE_CLIENT} --query_id=alter_00816_3;
    done
}

function thread4()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        echo "ALTER TABLE concurrent_alter_column ADD COLUMN f DOUBLE" | ${DATASTORE_CLIENT} --query_id=alter_00816_4;
        sleep "$(echo 0.0$RANDOM)";
        echo "ALTER TABLE concurrent_alter_column DROP COLUMN f" | ${DATASTORE_CLIENT} --query_id=alter_00816_4;
    done
}

TIMEOUT=20

thread1 2> /dev/null &
thread2 2> /dev/null &
thread3 2> /dev/null &
thread4 2> /dev/null &

wait

echo "DROP TABLE concurrent_alter_column SYNC" | ${DATASTORE_CLIENT}   # SYNC has effect only for Atomic database

# Wait for alters and check for deadlocks (in case of deadlock this loop will not finish)
while true; do
    echo "SELECT * FROM system.processes WHERE query_id LIKE 'alter\\_00816\\_%'" | ${DATASTORE_CLIENT} | grep -q -F 'alter' || break
    sleep 1;
done

echo 'did not crash'
