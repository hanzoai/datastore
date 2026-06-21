#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

$DATASTORE_CLIENT -q "
    DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1};
    DROP TABLE IF EXISTS table_for_dict1;
    DROP TABLE IF EXISTS table_for_dict2;

    CREATE TABLE table_for_dict1 (key_column UInt64, value_column String) ENGINE = MergeTree ORDER BY key_column;
    CREATE TABLE table_for_dict2 (key_column UInt64, value_column String) ENGINE = MergeTree ORDER BY key_column;

    INSERT INTO table_for_dict1 SELECT number, toString(number) from numbers(1000);
    INSERT INTO table_for_dict2 SELECT number, toString(number) from numbers(1000, 1000);

    CREATE DATABASE ${DATASTORE_DATABASE_1};

    CREATE DICTIONARY ${DATASTORE_DATABASE_1}.dict1 (key_column UInt64, value_column String) PRIMARY KEY key_column SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' PASSWORD '' DB '$DATASTORE_DATABASE')) LIFETIME(MIN 1 MAX 5) LAYOUT(FLAT());

    CREATE DICTIONARY ${DATASTORE_DATABASE_1}.dict2 (key_column UInt64, value_column String) PRIMARY KEY key_column SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict2' PASSWORD '' DB '$DATASTORE_DATABASE')) LIFETIME(MIN 1 MAX 5) LAYOUT(CACHE(SIZE_IN_CELLS 150));
"


function thread1()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT --query "SELECT * FROM system.dictionaries FORMAT Null"
    done
}

function thread2()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        DATASTORE_CLIENT --query "ATTACH DICTIONARY ${DATASTORE_DATABASE_1}.dict1" ||:
    done
}

function thread3()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        DATASTORE_CLIENT --query "ATTACH DICTIONARY ${DATASTORE_DATABASE_1}.dict2" ||:
    done
}


function thread4()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT -q "
            SELECT * FROM ${DATASTORE_DATABASE_1}.dict1 FORMAT Null;
            SELECT * FROM ${DATASTORE_DATABASE_1}.dict2 FORMAT Null;
        " ||:
    done
}

function thread5()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT -q "
            SELECT dictGetString('${DATASTORE_DATABASE_1}.dict1', 'value_column', toUInt64(number)) from numbers(1000) FROM FORMAT Null;
            SELECT dictGetString('${DATASTORE_DATABASE_1}.dict2', 'value_column', toUInt64(number)) from numbers(1000) FROM FORMAT Null;
        " ||:
    done
}

function thread6()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT -q "DETACH DICTIONARY ${DATASTORE_DATABASE_1}.dict1"
    done
}

function thread7()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT -q "DETACH DICTIONARY ${DATASTORE_DATABASE_1}.dict2"
    done
}

TIMEOUT=10

thread1 2> /dev/null &
thread2 2> /dev/null &
thread3 2> /dev/null &
thread4 2> /dev/null &
thread5 2> /dev/null &
thread6 2> /dev/null &
thread7 2> /dev/null &

thread1 2> /dev/null &
thread2 2> /dev/null &
thread3 2> /dev/null &
thread4 2> /dev/null &
thread5 2> /dev/null &
thread6 2> /dev/null &
thread7 2> /dev/null &

thread1 2> /dev/null &
thread2 2> /dev/null &
thread3 2> /dev/null &
thread4 2> /dev/null &
thread5 2> /dev/null &
thread6 2> /dev/null &
thread7 2> /dev/null &

thread1 2> /dev/null &
thread2 2> /dev/null &
thread3 2> /dev/null &
thread4 2> /dev/null &
thread5 2> /dev/null &
thread6 2> /dev/null &
thread7 2> /dev/null &

wait
$DATASTORE_CLIENT -q "SELECT 'Still alive'"

$DATASTORE_CLIENT -q "ATTACH DICTIONARY IF NOT EXISTS ${DATASTORE_DATABASE_1}.dict1"
$DATASTORE_CLIENT -q "ATTACH DICTIONARY IF NOT EXISTS ${DATASTORE_DATABASE_1}.dict2"

$DATASTORE_CLIENT -q "
    DROP DATABASE ${DATASTORE_DATABASE_1};
    DROP TABLE table_for_dict1;
    DROP TABLE table_for_dict2;
"
