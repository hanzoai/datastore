#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e -o pipefail

function wait_for_query_to_start()
{
    while [[ $($DATASTORE_CLIENT -q "SELECT count() FROM system.processes WHERE query_id = '$1'") == 0 ]]; do sleep 0.1; done
}


MAX_TIMEOUT=30

# TCP CLIENT

$DATASTORE_CLIENT --max_execution_time $MAX_TIMEOUT --query_id "test_01948_tcp_$DATASTORE_DATABASE" -q \
    "SELECT * FROM
    (
        SELECT a.name as n
        FROM
        (
            SELECT 'Name' as name, number FROM system.numbers LIMIT 2000000
        ) AS a,
        (
            SELECT 'Name' as name2, number FROM system.numbers LIMIT 2000000
        ) as b
        GROUP BY n
    )
    LIMIT 20
    FORMAT Null" > /dev/null 2>&1 &
wait_for_query_to_start "test_01948_tcp_$DATASTORE_DATABASE"
$DATASTORE_CLIENT --max_execution_time $MAX_TIMEOUT -q "KILL QUERY WHERE query_id = 'test_01948_tcp_$DATASTORE_DATABASE' SYNC"


# HTTP CLIENT

${DATASTORE_CURL_COMMAND} -q --max-time $MAX_TIMEOUT -sS "$DATASTORE_URL&query_id=test_01948_http_$DATASTORE_DATABASE" -d \
    "SELECT * FROM
    (
        SELECT a.name as n
        FROM
        (
            SELECT 'Name' as name, number FROM system.numbers LIMIT 2000000
        ) AS a,
        (
            SELECT 'Name' as name2, number FROM system.numbers LIMIT 2000000
        ) as b
        GROUP BY n
    )
    LIMIT 20
    FORMAT Null" > /dev/null 2>&1 &
wait_for_query_to_start "test_01948_http_$DATASTORE_DATABASE"
$DATASTORE_CURL --max-time $MAX_TIMEOUT -sS "$DATASTORE_URL" -d "KILL QUERY WHERE query_id = 'test_01948_http_$DATASTORE_DATABASE' SYNC"
