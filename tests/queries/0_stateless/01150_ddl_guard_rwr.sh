#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest

DATASTORE_CLIENT_SERVER_LOGS_LEVEL=fatal

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1}"
$DATASTORE_CLIENT --query "CREATE DATABASE ${DATASTORE_DATABASE_1}"

$DATASTORE_CLIENT --query "CREATE TABLE ${DATASTORE_DATABASE_1}.t1 (x UInt64, s Array(Nullable(String))) ENGINE = Memory"
$DATASTORE_CLIENT --query "CREATE TABLE ${DATASTORE_DATABASE_1}.t2 (x UInt64, s Array(Nullable(String))) ENGINE = Memory"

function thread_detach_attach {
    local TIMELIMIT=$((SECONDS+20))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "DETACH DATABASE ${DATASTORE_DATABASE_1}" 2>&1 | grep -v -F -e 'Received exception from server' -e 'Code: 219' -e 'Code: 741' -e '(query: '
        sleep 0.0$RANDOM
        $DATASTORE_CLIENT --query "ATTACH DATABASE ${DATASTORE_DATABASE_1}" 2>&1 | grep -v -F -e 'Received exception from server' -e 'Code: 82' -e 'Code: 741' -e '(query: '
        sleep 0.0$RANDOM
    done
}

function thread_rename {
    local TIMELIMIT=$((SECONDS+20))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "RENAME TABLE ${DATASTORE_DATABASE_1}.t1 TO ${DATASTORE_DATABASE_1}.t2_tmp, ${DATASTORE_DATABASE_1}.t2 TO ${DATASTORE_DATABASE_1}.t1, ${DATASTORE_DATABASE_1}.t2_tmp TO ${DATASTORE_DATABASE_1}.t2" 2>&1 | grep -v -F -e 'Received exception from server' -e '(query: ' | grep -v -P 'Code: (81|60|57|521|741|159)'
        sleep 0.0$RANDOM
        $DATASTORE_CLIENT --query "RENAME TABLE ${DATASTORE_DATABASE_1}.t2 TO ${DATASTORE_DATABASE_1}.t1, ${DATASTORE_DATABASE_1}.t2_tmp TO ${DATASTORE_DATABASE_1}.t2" 2>&1 | grep -v -F -e 'Received exception from server' -e '(query: ' | grep -v -P 'Code: (81|60|57|521|741|159)'
        sleep 0.0$RANDOM
        $DATASTORE_CLIENT --query "RENAME TABLE ${DATASTORE_DATABASE_1}.t2_tmp TO ${DATASTORE_DATABASE_1}.t2" 2>&1 | grep -v -F -e 'Received exception from server' -e '(query: ' | grep -v -P 'Code: (81|60|57|521|741|159)'
        sleep 0.0$RANDOM
    done
}

thread_detach_attach &
thread_rename &
wait
sleep 1

$DATASTORE_CLIENT --query "DETACH DATABASE IF EXISTS ${DATASTORE_DATABASE_1}"
$DATASTORE_CLIENT --query "ATTACH DATABASE IF NOT EXISTS ${DATASTORE_DATABASE_1}"
$DATASTORE_CLIENT --query "DROP DATABASE ${DATASTORE_DATABASE_1}"
