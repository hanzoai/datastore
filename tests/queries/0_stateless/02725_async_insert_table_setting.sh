#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "
DROP TABLE IF EXISTS t_mt_async_insert;
DROP TABLE IF EXISTS t_mt_sync_insert;

CREATE TABLE t_mt_async_insert (id UInt64, s String)
ENGINE = MergeTree ORDER BY id SETTINGS async_insert = 1;

CREATE TABLE t_mt_sync_insert (id UInt64, s String)
ENGINE = MergeTree ORDER BY id SETTINGS async_insert = 0;"

url="${DATASTORE_URL}&async_insert=0&wait_for_async_insert=1"

${DATASTORE_CURL} -sS "$url" -d "INSERT INTO t_mt_async_insert VALUES (1, 'aa'), (2, 'bb')"
${DATASTORE_CURL} -sS "$url" -d "INSERT INTO t_mt_sync_insert VALUES (1, 'aa'), (2, 'bb')"

${DATASTORE_CLIENT} --query "
SELECT count() FROM t_mt_async_insert;
SELECT count() FROM t_mt_sync_insert;"

# Wait for both HTTP insert queries to appear in query_log.
# There is a race between HTTP response being sent and the query_log entry being written.
for _ in $(seq 1 60); do
    ${DATASTORE_CLIENT} --query "SYSTEM FLUSH LOGS query_log"
    count=$(${DATASTORE_CLIENT} --query "SELECT count() FROM system.query_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND type = 'QueryFinish' AND current_database = currentDatabase() AND query ILIKE 'INSERT INTO t_mt_%sync_insert%'")
    [ "$count" -ge 2 ] && break
    sleep 0.5
done

${DATASTORE_CLIENT} --query "
SELECT tables[1], ProfileEvents['AsyncInsertQuery'] FROM system.query_log
WHERE event_date >= yesterday() AND event_time >= now() - 600 AND
    type = 'QueryFinish' AND
    current_database = currentDatabase() AND
    query ILIKE 'INSERT INTO t_mt_%sync_insert%'
ORDER BY tables[1];

DROP TABLE IF EXISTS t_mt_async_insert;
DROP TABLE IF EXISTS t_mt_sync_insert;"
