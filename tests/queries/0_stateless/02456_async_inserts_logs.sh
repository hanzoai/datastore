#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS t_async_inserts_logs"
${DATASTORE_CLIENT} -q "CREATE TABLE t_async_inserts_logs (id UInt32, s String) ENGINE = MergeTree ORDER BY id"

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO t_async_inserts_logs FORMAT JSONEachRow {"id": 5, "s": "e"} {"id": 6, "s": "f"}' &
${DATASTORE_CURL} -sS "$url" -d "INSERT INTO t_async_inserts_logs VALUES (1, 'a')" &

${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO t_async_inserts_logs FORMAT JSONEachRow qqqqqq' > /dev/null 2>&1 &
${DATASTORE_CURL} -sS "$url" -d 'INSERT INTO t_async_inserts_logs VALUES qqqqqq' > /dev/null 2>&1 &

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO FUNCTION remote('127.0.0.1', currentDatabase(), t_async_inserts_logs) VALUES (1, 'aaa') (2, 'bbb')" &

wait

${DATASTORE_CLIENT} -q "OPTIMIZE TABLE t_async_inserts_logs FINAL"
${DATASTORE_CLIENT} -q "ALTER TABLE t_async_inserts_logs MODIFY SETTING parts_to_throw_insert = 1"

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO t_async_inserts_logs VALUES (1, 'a')" > /dev/null 2>&1 &

wait

${DATASTORE_CLIENT} -q "SELECT count() FROM t_async_inserts_logs"

# Wait for all async insert log entries.
# There is a race between HTTP response being sent and the log entry being written.
for _ in $(seq 1 60); do
    ${DATASTORE_CLIENT} -q "SYSTEM FLUSH LOGS asynchronous_insert_log"
    count=$(${DATASTORE_CLIENT} -q "SELECT count() FROM system.asynchronous_insert_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND (database = '$DATASTORE_DATABASE' AND table = 't_async_inserts_logs' OR query ILIKE 'INSERT INTO FUNCTION%$DATASTORE_DATABASE%t_async_inserts_logs%') AND data_kind = 'Parsed'")
    [ "$count" -ge 6 ] && break
    sleep 0.5
done
${DATASTORE_CLIENT} -q "
    SELECT table, format, bytes, rows, empty(exception), status,
    status = 'ParsingError' ? flush_time_microseconds = 0 : flush_time_microseconds > event_time_microseconds AS time_ok
    FROM system.asynchronous_insert_log
    WHERE event_date >= yesterday() AND event_time >= now() - 600 AND
    (
        database = '$DATASTORE_DATABASE' AND table = 't_async_inserts_logs'
        OR query ILIKE 'INSERT INTO FUNCTION%$DATASTORE_DATABASE%t_async_inserts_logs%'
    )
    AND data_kind = 'Parsed'
    ORDER BY table, status, format"

${DATASTORE_CLIENT} -q "DROP TABLE t_async_inserts_logs"

${DATASTORE_CLIENT} -q "
SELECT event, value > 0 FROM system.events
WHERE event IN ('AsyncInsertQuery', 'AsyncInsertBytes', 'AsyncInsertRows')
ORDER BY event"
