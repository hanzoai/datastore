#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS async_inserts"
${DATASTORE_CLIENT} -q "CREATE TABLE async_inserts (id UInt32, v UInt32 DEFAULT id * id) ENGINE = Memory"

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT CSV
1,
2,' &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT CSV
3,
4,
' &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 5} {"id": 6}' &
${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 7} {"id": 8}' &

wait

${DATASTORE_CLIENT} -q "SELECT * FROM async_inserts ORDER BY id"

${DATASTORE_CLIENT} -q "DROP TABLE async_inserts"
