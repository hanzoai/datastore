#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS async_inserts"
${DATASTORE_CLIENT} -q "CREATE TABLE async_inserts (id UInt32, s String) ENGINE = MergeTree ORDER BY id SETTINGS parts_to_throw_insert = 1"
${DATASTORE_CLIENT} -q "SYSTEM STOP MERGES $DATASTORE_DATABASE.async_inserts"

${DATASTORE_CLIENT} -q "INSERT INTO async_inserts VALUES (1, 's')"

for _ in {1..3}; do
    ${DATASTORE_CURL} -sS $url -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 2, "s": "a"} {"id": 3, "s": "b"}' \
        | grep -o "Too many parts" &
done

wait

${DATASTORE_CLIENT} -q "DROP TABLE async_inserts"
