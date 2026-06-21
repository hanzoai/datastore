#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

message="INSERT query will be executed synchronously because it has too much data"

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS t_async_insert_fallback"
$DATASTORE_CLIENT --query "CREATE TABLE t_async_insert_fallback (a UInt64) ENGINE = Memory"

query_id_suffix="${DATASTORE_DATABASE}_${RANDOM}"

# inlined data via native protocol
$DATASTORE_CLIENT \
    --query_id "0_$query_id_suffix" \
    --async_insert 1 \
    --async_insert_max_data_size 5 \
    --query "INSERT INTO t_async_insert_fallback VALUES (1) (2) (3)"

# inlined data via http
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query_id=1_$query_id_suffix&async_insert=1&async_insert_max_data_size=3" \
    -d "INSERT INTO t_async_insert_fallback VALUES (4) (5) (6)"

# partially inlined partially sent via post data
${DATASTORE_CURL} -sS -X POST \
    "${DATASTORE_URL}&query_id=2_$query_id_suffix&async_insert=1&async_insert_max_data_size=5&query=INSERT+INTO+t_async_insert_fallback+VALUES+(7)" \
    --data-binary @- <<< "(8) (9)"

# partially inlined partially sent via post data
${DATASTORE_CURL} -sS -X POST \
    "${DATASTORE_URL}&query_id=3_$query_id_suffix&async_insert=1&async_insert_max_data_size=5&query=INSERT+INTO+t_async_insert_fallback+VALUES+(10)+(11)" \
    --data-binary @- <<< "(12)"

# sent via post data
${DATASTORE_CURL} -sS -X POST \
    "${DATASTORE_URL}&query_id=4_$query_id_suffix&async_insert=1&async_insert_max_data_size=5&query=INSERT+INTO+t_async_insert_fallback+FORMAT+Values" \
    --data-binary @- <<< "(13) (14) (15)"

# no limit for async insert size
${DATASTORE_CURL} -sS -X POST \
    "${DATASTORE_URL}&query_id=5_$query_id_suffix&async_insert=1&query=INSERT+INTO+t_async_insert_fallback+FORMAT+Values" \
    --data-binary @- <<< "(16) (17) (18)"

$DATASTORE_CLIENT --query "SELECT * FROM t_async_insert_fallback ORDER BY a"
# Wait for text_log fallback entries.
# There is a race between HTTP response being sent and the log entry being written.
for _ in $(seq 1 60); do
    $DATASTORE_CLIENT --query "SYSTEM FLUSH LOGS text_log"
    count=$($DATASTORE_CLIENT --query "SELECT count() FROM system.text_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND query_id LIKE '%$query_id_suffix' AND message LIKE '%$message%' SETTINGS max_rows_to_read = 0")
    [ "$count" -ge 5 ] && break
    sleep 0.5
done
$DATASTORE_CLIENT --query "
    SELECT 'id_' || splitByChar('_', query_id)[1] AS id FROM system.text_log
    WHERE event_date >= yesterday() AND event_time >= now() - 600 AND query_id LIKE '%$query_id_suffix' AND message LIKE '%$message%'
    ORDER BY id
    SETTINGS max_rows_to_read = 0
"

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS t_async_insert_fallback"
