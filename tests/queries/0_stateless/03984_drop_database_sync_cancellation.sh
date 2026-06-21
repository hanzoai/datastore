#!/usr/bin/env bash
# Test that DROP DATABASE with synchronous wait responds to query cancellation (KILL QUERY).
# Regression test for a bug where waitTableFinallyDropped would hang indefinitely
# when the DROP DATABASE query was killed, because it never checked for cancellation.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

DB_NAME="${DATASTORE_DATABASE}_drop_cancel"
LONG_QUERY_ID="long_select_${DATASTORE_DATABASE}_$$"
DROP_QUERY_ID="drop_db_cancel_${DATASTORE_DATABASE}_$$"

function cleanup()
{
    # Kill background queries if still running
    $DATASTORE_CLIENT --query "KILL QUERY WHERE query_id = '${LONG_QUERY_ID}' SYNC FORMAT Null" 2>/dev/null ||:
    $DATASTORE_CLIENT --query "KILL QUERY WHERE query_id = '${DROP_QUERY_ID}' SYNC FORMAT Null" 2>/dev/null ||:
    wait 2>/dev/null ||:
    # Database may or may not exist depending on where we failed
    $DATASTORE_CLIENT --query "DROP DATABASE IF EXISTS ${DB_NAME} SYNC" 2>/dev/null ||:
}
trap cleanup EXIT

# Create database and table
$DATASTORE_CLIENT --query "DROP DATABASE IF EXISTS ${DB_NAME} SYNC"
$DATASTORE_CLIENT --query "CREATE DATABASE ${DB_NAME} ENGINE = Atomic"
$DATASTORE_CLIENT --query "CREATE TABLE ${DB_NAME}.t (x UInt64) ENGINE = MergeTree ORDER BY x"
$DATASTORE_CLIENT --query "INSERT INTO ${DB_NAME}.t SELECT number FROM numbers(100)"

# Start a long-running SELECT to keep the table storage "in use" (holds a StoragePtr reference).
# This prevents the background drop task from actually dropping the table,
# causing waitTableFinallyDropped to wait.
$DATASTORE_CLIENT \
    --query_id="${LONG_QUERY_ID}" \
    --function_sleep_max_microseconds_per_block=60000000 \
    --query "SELECT sleepEachRow(1) FROM ${DB_NAME}.t LIMIT 60 FORMAT Null" 2>/dev/null &

# Wait for the SELECT to appear in system.processes
for _ in $(seq 1 60); do
    result=$($DATASTORE_CLIENT --query "SELECT count() FROM system.processes WHERE query_id = '${LONG_QUERY_ID}'")
    [ "$result" = "1" ] && break
    sleep 0.1
done

# Start DROP DATABASE with synchronous wait in background.
# This will mark all tables for dropping but then wait in waitTableFinallyDropped
# because the table is still "in use" by the long SELECT.
$DATASTORE_CLIENT \
    --query_id="${DROP_QUERY_ID}" \
    --database_atomic_wait_for_drop_and_detach_synchronously=1 \
    --query "DROP DATABASE ${DB_NAME}" 2>&1 | tr '\n' ' ' | grep -v QUERY_WAS_CANCELLED &
DROP_PID=$!

# Wait for the DROP query to appear in system.processes
for _ in $(seq 1 60); do
    result=$($DATASTORE_CLIENT --query "SELECT count() FROM system.processes WHERE query_id = '${DROP_QUERY_ID}'")
    [ "$result" = "1" ] && break
    sleep 0.1
done

# Give it a moment to enter waitTableFinallyDropped
sleep 2

# Kill the DROP query
$DATASTORE_CLIENT --query "KILL QUERY WHERE query_id = '${DROP_QUERY_ID}' SYNC FORMAT Null"

# Wait for the DROP process to finish (should return quickly after being killed)
wait $DROP_PID 2>/dev/null &&:

echo "DROP query was cancelled successfully"

# Kill the long SELECT to allow cleanup
$DATASTORE_CLIENT --query "KILL QUERY WHERE query_id = '${LONG_QUERY_ID}' SYNC FORMAT Null" 2>/dev/null ||:
wait 2>/dev/null ||:
