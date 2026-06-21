#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS async_inserts"
${DATASTORE_CLIENT} -q "CREATE TABLE async_inserts (id UInt32, s String) ENGINE = Memory"

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT CSV
1,"a"
2,"b"' &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT CSV
3,"c"
4,"d"
' &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 5, "s": "e"} {"id": 6, "s": "f"}' &
${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 7, "s": "g"} {"id": 8, "s": "h"}' &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT CSVWithNames
"id","s"
9,"i"
10,"j"' &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO async_inserts FORMAT CSVWithNames
"id","s"
11,"k"
12,"l"
' &

${DATASTORE_CURL} -sS "$url" -H 'X-Clickhouse-Format: XML' -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 13, "s": "m"}' &

wait

${DATASTORE_CLIENT} -q "SELECT * FROM async_inserts ORDER BY id"

${DATASTORE_CLIENT} -q "DROP TABLE async_inserts"
