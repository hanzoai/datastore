#!/usr/bin/env bash
# Tags: no-fasttest


CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

function thread_query()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "SELECT count() FROM numbers_mt(10000) WHERE rand() = 0 FORMAT Null";
    done
}

function thread_cancel()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "KILL QUERY WHERE current_database = '$DATASTORE_DATABASE' SYNC FORMAT Null";
    done
}

TIMEOUT=30

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

thread_query 2> /dev/null &
thread_cancel 2> /dev/null &

wait
