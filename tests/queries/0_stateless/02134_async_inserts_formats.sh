#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# With adaptive timeout enabled, the asynchronous queue can be flushed synchronously, depending on the elapsed since the last insert.
# This may result in test flakiness.
url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1&async_insert_use_adaptive_busy_timeout=0"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS async_inserts"
${DATASTORE_CLIENT} -q "CREATE TABLE async_inserts (id UInt32, s String) ENGINE = MergeTree ORDER BY id"

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO async_inserts settings format_custom_escaping_rule='CSV', format_custom_field_delimiter=',' FORMAT CustomSeparated
1,\"a\"
2,\"b\"
" &

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO async_inserts settings format_custom_escaping_rule='CSV', format_custom_field_delimiter=',' FORMAT CustomSeparated
3,\"a\"
4,\"b\"
" &

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO async_inserts settings format_custom_escaping_rule='CSV', format_custom_field_delimiter=',' FORMAT CustomSeparatedWithNames
\"id\",\"s\"
5,\"a\"
6,\"b\"
" &

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO async_inserts settings format_custom_escaping_rule='CSV', format_custom_field_delimiter=',' FORMAT CustomSeparatedWithNames
\"id\",\"s\"
7,\"a\"
8,\"b\"
" &

wait

${DATASTORE_CLIENT} -q "SELECT * FROM async_inserts ORDER BY id"
${DATASTORE_CLIENT} -q "SELECT name, rows, level FROM system.parts WHERE table = 'async_inserts' AND database = '$DATASTORE_DATABASE' ORDER BY name"

${DATASTORE_CLIENT} -q "DROP TABLE async_inserts"
