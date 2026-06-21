#!/usr/bin/env bash
# Tags: deadlock, shard, no-parallel

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test1";
$DATASTORE_CLIENT --query "CREATE TABLE test1 (x UInt8) ENGINE = MergeTree ORDER BY tuple()";

function thread1()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "ALTER TABLE test1 MODIFY COLUMN x Nullable(UInt8)"
        $DATASTORE_CLIENT --query "ALTER TABLE test1 MODIFY COLUMN x UInt8"
    done
}

function thread2()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "SELECT x FROM test1 WHERE x IN (SELECT x FROM remote('127.0.0.2', '$DATASTORE_DATABASE', test1))" --format Null
    done
}

TIMEOUT=10

thread1 2> /dev/null &
thread2 2> /dev/null &

thread1 2> /dev/null &
thread2 2> /dev/null &

thread1 2> /dev/null &
thread2 2> /dev/null &

thread1 2> /dev/null &
thread2 2> /dev/null &

wait

$DATASTORE_CLIENT -q "DROP TABLE test1"
