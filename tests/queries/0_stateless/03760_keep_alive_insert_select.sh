#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

DATASTORE_URL="${DATASTORE_URL}&http_wait_end_of_query=1"

${DATASTORE_CURL} -sS "${DATASTORE_URL}" -H 'Accept-Encoding: gzip' \
    -d 'DROP TABLE IF EXISTS insert_number_table'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -H 'Accept-Encoding: gzip' \
    -d 'CREATE TABLE insert_number_table (record UInt32) Engine = Memory'

query_id=$(
    ${DATASTORE_CURL} -vsS "${DATASTORE_URL}&max_block_size=1&http_headers_progress_interval_ms=10&send_progress_in_http_headers=1" \
    -d 'INSERT INTO insert_number_table (record) SELECT number FROM system.numbers LIMIT 10' 2>&1 \
    | grep -F '< X-Datastore-Query-Id:' | sed 's/< X-Datastore-Query-Id: //' | tr -d '\n\t\r' | xargs
)

${DATASTORE_CURL} -sS "${DATASTORE_URL}" \
    -d "SYSTEM FLUSH LOGS text_log"

# Use max_threads=0 to avoid randomized max_threads limiting parallelism,
# which can make scanning system.text_log too slow under TSan.
${DATASTORE_CURL} -sS "${DATASTORE_URL}&max_threads=0" \
    -d "SELECT message_format_string FROM system.text_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND level='Error' AND query_id='${query_id}' AND message_format_string = 'Request stream is shared by multiple threads. HTTP keep alive is not possible. Use count {}'"

${DATASTORE_CURL} -sS "${DATASTORE_URL}" -H 'Accept-Encoding: gzip' \
    -d 'DROP TABLE insert_number_table'
