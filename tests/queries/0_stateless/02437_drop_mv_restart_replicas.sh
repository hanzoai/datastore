#!/usr/bin/env bash
# Tags: long, zookeeper, race, no-ordinary-database, no-replicated-database
# FIXME remove no-replicated-database tag

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "create user u_$DATASTORE_DATABASE"
$DATASTORE_CLIENT -q "grant all on db_$DATASTORE_DATABASE.* to u_$DATASTORE_DATABASE"

# For tests with Replicated
ENGINE=$($DATASTORE_CLIENT -q "select replace(engine_full, '$DATASTORE_DATABASE', 'db_$DATASTORE_DATABASE') from system.databases where name='$DATASTORE_DATABASE' format TSVRaw")
export ENGINE

function thread_ddl()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT -q "create database if not exists db_$DATASTORE_DATABASE engine=$ENGINE"
        $DATASTORE_CLIENT -q "CREATE TABLE if not exists db_$DATASTORE_DATABASE.test (test String, A Int64, B Int64) ENGINE = ReplicatedMergeTree ('/datastore/tables/{database}/test_02124/{table}', '1') ORDER BY tuple();"
        $DATASTORE_CLIENT -q "CREATE MATERIALIZED VIEW if not exists db_$DATASTORE_DATABASE.test_mv_a Engine=ReplicatedMergeTree ('/datastore/tables/{database}/test_02124/{table}', '1') order by tuple() AS SELECT test, A, count() c FROM db_$DATASTORE_DATABASE.test group by test, A;"
        $DATASTORE_CLIENT -q "CREATE MATERIALIZED VIEW if not exists db_$DATASTORE_DATABASE.test_mv_b Engine=ReplicatedMergeTree ('/datastore/tables/{database}/test_02124/{table}', '1') partition by A order by tuple() AS SELECT test, A, count() c FROM db_$DATASTORE_DATABASE.test group by test, A;"
        $DATASTORE_CLIENT -q "CREATE MATERIALIZED VIEW if not exists db_$DATASTORE_DATABASE.test_mv_c Engine=ReplicatedMergeTree ('/datastore/tables/{database}/test_02124/{table}', '1') order by tuple() AS SELECT test, A, count() c FROM db_$DATASTORE_DATABASE.test group by test, A;"
        sleep 0.$RANDOM;

        # A kind of backoff
        timeout 5s $DATASTORE_CLIENT -q "select sleepEachRow(0.1) from system.dropped_tables format Null" 2>/dev/null ||:

        $DATASTORE_CLIENT -q "drop database if exists db_$DATASTORE_DATABASE"
    done
}

function thread_insert()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        $DATASTORE_CLIENT -q "INSERT INTO db_$DATASTORE_DATABASE.test SELECT 'case1', number%3, rand() FROM numbers(5)"
        sleep 0.$RANDOM;
    done
}

function thread_restart()
{
    local TIMELIMIT=$((SECONDS+TIMEOUT))
    while [ $SECONDS -lt "$TIMELIMIT" ]
    do
        # The simplest way to restart only replicas from a specific database is to use a special user
        $DATASTORE_CLIENT --user "u_$DATASTORE_DATABASE" -q "system restart replicas"
        sleep 0.$RANDOM;
    done
}

TIMEOUT=15

thread_ddl 2>&1| grep -Fa "Exception: " | grep -Fv -e "TABLE_IS_DROPPED" -e "UNKNOWN_TABLE" -e "DATABASE_NOT_EMPTY" -e "TABLE_IS_BEING_RESTARTED" &
thread_insert 2> /dev/null &
thread_restart 2>&1| grep -Fa "Exception: " | grep -Fv -e "is currently dropped or renamed" -e "is being dropped or detached" &

wait

timeout 45s $DATASTORE_CLIENT -q "select sleepEachRow(0.3) from system.dropped_tables format Null" 2>/dev/null ||:

$DATASTORE_CLIENT -q "drop database if exists db_$DATASTORE_DATABASE" 2>&1| grep -Fa "Exception: " | grep -Fv -e "TABLE_IS_DROPPED" -e "UNKNOWN_TABLE" -e "DATABASE_NOT_EMPTY" ||:
