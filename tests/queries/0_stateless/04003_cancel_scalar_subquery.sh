#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query_id="$DATASTORE_TEST_UNIQUE_NAME" --query="SELECT (SELECT max(number) FROM system.numbers) + 1 SETTINGS max_rows_to_read = 0, max_bytes_to_read = 0" >/dev/null 2>&1 &
client_pid=$!

for _ in {0..60}
do
    $DATASTORE_CLIENT --query "SELECT count() > 0 FROM system.processes WHERE query_id = '$DATASTORE_TEST_UNIQUE_NAME'" | grep -qF '1' && break
    sleep 0.5
done

kill -INT $client_pid
wait $client_pid

$DATASTORE_CLIENT --query "SYSTEM FLUSH LOGS query_log"
$DATASTORE_CLIENT --query "SELECT exception FROM system.query_log WHERE query_id = '$DATASTORE_TEST_UNIQUE_NAME' AND current_database = '$DATASTORE_DATABASE'" | grep -oF "QUERY_WAS_CANCELLED"

# Test cancellation of IN subquery with a MergeTree table
$DATASTORE_CLIENT --query "CREATE TABLE ${DATASTORE_TEST_UNIQUE_NAME}_t (col UInt64) ENGINE = MergeTree() ORDER BY col"
$DATASTORE_CLIENT --query "INSERT INTO ${DATASTORE_TEST_UNIQUE_NAME}_t VALUES (rand()), (rand()), (rand())"

query_id="${DATASTORE_TEST_UNIQUE_NAME}_in"
$DATASTORE_CLIENT --query_id="$query_id" --query="SELECT * FROM ${DATASTORE_TEST_UNIQUE_NAME}_t WHERE col IN (SELECT max(rand()) FROM system.numbers) SETTINGS max_rows_to_read = 0, max_bytes_to_read = 0" >/dev/null 2>&1 &
client_pid=$!

for _ in {0..60}
do
    $DATASTORE_CLIENT --query "SELECT count() > 0 FROM system.processes WHERE query_id = '$query_id'" | grep -qF '1' && break
    sleep 0.5
done

kill -INT $client_pid
wait $client_pid

$DATASTORE_CLIENT --query "SYSTEM FLUSH LOGS query_log"
$DATASTORE_CLIENT --query "SELECT exception FROM system.query_log WHERE query_id = '$query_id' AND current_database = '$DATASTORE_DATABASE'" | grep -oF "QUERY_WAS_CANCELLED"

$DATASTORE_CLIENT --query "DROP TABLE ${DATASTORE_TEST_UNIQUE_NAME}_t"
