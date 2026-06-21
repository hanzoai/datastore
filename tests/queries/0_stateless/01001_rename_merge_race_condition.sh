#!/usr/bin/env bash
# Tags: race

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test1";
$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test2";
$DATASTORE_CLIENT --query "CREATE TABLE test1 (x UInt64) ENGINE = Memory";


function thread1()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        seq 1 50 | sed -r -e 's/.+/RENAME TABLE test1 TO test2; RENAME TABLE test2 TO test1;/' | $DATASTORE_CLIENT -n
    done
}

function thread2()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "SELECT * FROM merge('$DATASTORE_DATABASE', '^test[12]$')"
    done
}

TIMEOUT=10

thread1 2> /dev/null &
thread2 2> /dev/null &

wait

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test1";
$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test2";
