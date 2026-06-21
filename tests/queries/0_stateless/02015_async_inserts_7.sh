#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS async_inserts"
${DATASTORE_CLIENT} -q "CREATE TABLE async_inserts (id UInt32, s String) ENGINE = Memory"

${DATASTORE_CURL} -sS $url -d "INSERT INTO async_inserts VALUES (1, 'a') (2, 'b')" &
${DATASTORE_CURL} -sS $url -d "INSERT INTO async_inserts VALUES (3, 'c'), (4, 'd')" &
${DATASTORE_CURL} -sS $url -d "INSERT INTO async_inserts VALUES (5, 'e'), (6, 'f'), " &

wait

${DATASTORE_CLIENT} -q "SELECT * FROM async_inserts ORDER BY id"

${DATASTORE_CLIENT} -q "DROP TABLE async_inserts"
