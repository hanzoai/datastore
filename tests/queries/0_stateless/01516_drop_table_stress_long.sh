#!/usr/bin/env bash
# Tags: long, no-debug, no-azure-blob-storage

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

export CURR_DATABASE="test_01516_${DATASTORE_DATABASE}"

function drop_database()
{
    # redirect stderr since it is racy with DROP TABLE
    # and tries to remove ${CURR_DATABASE}.data too.
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "DROP DATABASE IF EXISTS ${CURR_DATABASE}" 2>/dev/null
}
trap drop_database EXIT

function drop_table()
{
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "DROP TABLE IF EXISTS ${CURR_DATABASE}.data3;" 2>&1 | grep -F "Code: " | grep -Fv "is currently dropped or renamed"
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "DROP TABLE IF EXISTS ${CURR_DATABASE}.data1;" 2>&1 | grep -F "Code: " | grep -Fv "is currently dropped or renamed"
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "DROP TABLE IF EXISTS ${CURR_DATABASE}.data2;" 2>&1 | grep -F "Code: " | grep -Fv "is currently dropped or renamed"
}

function create()
{
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "CREATE DATABASE IF NOT EXISTS ${CURR_DATABASE};"
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "CREATE TABLE IF NOT EXISTS ${CURR_DATABASE}.data1 Engine=MergeTree() ORDER BY number AS SELECT * FROM numbers(1);" 2>&1 | grep -F "Code: " | grep -Fv "is currently dropped or renamed"
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "CREATE TABLE IF NOT EXISTS ${CURR_DATABASE}.data2 Engine=MergeTree() ORDER BY number AS SELECT * FROM numbers(1);" 2>&1 | grep -F "Code: " | grep -Fv "is currently dropped or renamed"
    ${DATASTORE_CLIENT} --fsync_metadata=0 -q "CREATE TABLE IF NOT EXISTS ${CURR_DATABASE}.data3 Engine=MergeTree() ORDER BY number AS SELECT * FROM numbers(1);" 2>&1 | grep -F "Code: " | grep -Fv "is currently dropped or renamed"
}

for _ in {1..25}; do
    create
    drop_table &
    drop_database &
    wait
done
