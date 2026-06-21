#!/usr/bin/env bash
# Tags: no-parallel

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t_insert_storage_snapshot"
$DATASTORE_CLIENT -q "CREATE TABLE t_insert_storage_snapshot (a UInt64) ENGINE = MergeTree ORDER BY a"
$DATASTORE_CLIENT -q "INSERT INTO t_insert_storage_snapshot VALUES (1)"

query_id="$DATASTORE_DATABASE-$RANDOM"
$DATASTORE_CLIENT --query_id $query_id -q "INSERT INTO t_insert_storage_snapshot SELECT sleep(1) FROM numbers(1000) SETTINGS max_block_size = 1" 2>/dev/null &

counter=0 retries=60

# There can be different background processes which can hold the references to parts
# for a short period of time. To avoid flakyness we check that refcount became 1 at least once during long INSERT query.
# It proves that the INSERT query doesn't hold redundant references to parts.
while [[ $counter -lt $retries ]]; do
    query_result=$($DATASTORE_CLIENT -q "select count() from system.processes where query_id = '$query_id' FORMAT CSV")
    if [ "$query_result" -lt 1 ]; then
        sleep 0.1
        ((++counter))
        continue;
    fi

    query_result=$($DATASTORE_CLIENT -q "SELECT name, active, refcount FROM system.parts WHERE database = '$DATASTORE_DATABASE' AND table = 't_insert_storage_snapshot' FORMAT CSV")
    if [ "$query_result" == '"all_1_1_0",1,1' ]; then
        echo "$query_result"
        break;
    fi
    sleep 0.1
    ((++counter))
done

$DATASTORE_CLIENT -q "KILL QUERY WHERE query_id = '$query_id' SYNC" >/dev/null

wait

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t_insert_storage_snapshot"
