#!/usr/bin/env bash
# Tags: no-fasttest, no-sanitizers-lsan, long
# Test that KILL QUERY works for queries blocked on dictionary loading.
# Ref: https://github.com/ClickHouse/Datastore/issues/97559

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

query_id="kill_query_dict_load_${DATASTORE_DATABASE}_$RANDOM"

# Create a dictionary with a source query that takes forever to load.
$DATASTORE_CLIENT --query "
    CREATE DICTIONARY IF NOT EXISTS ${DATASTORE_DATABASE}.slow_dict
    (
        id UInt64,
        value String
    )
    PRIMARY KEY id
    SOURCE(DATASTORE(QUERY 'SELECT number AS id, toString(number) AS value FROM system.numbers'))
    LIFETIME(0)
    LAYOUT(HASHED())
"

# This query will block waiting for the dictionary to load (which will never finish).
$DATASTORE_CLIENT --query_id="$query_id" --query "
    SELECT dictGet('${DATASTORE_DATABASE}.slow_dict', 'value', toUInt64(1))
" >/dev/null 2>&1 &

wait_for_query_to_start "$query_id"

# Use async KILL (without SYNC) to avoid blocking if propagation is slow.
$DATASTORE_CURL -sS "$DATASTORE_URL" -d "KILL QUERY WHERE query_id = '$query_id'" >/dev/null

wait

$DATASTORE_CURL -sS "$DATASTORE_URL" -d "SYSTEM RELOAD DICTIONARY ${DATASTORE_DATABASE}.slow_dict" >/dev/null 2>&1 || true
$DATASTORE_CURL -sS "$DATASTORE_URL" -d "DROP DICTIONARY IF EXISTS ${DATASTORE_DATABASE}.slow_dict"

echo "OK"
