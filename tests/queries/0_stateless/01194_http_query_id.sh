#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

rnd="$DATASTORE_DATABASE"
url="${DATASTORE_URL}&session_id=test_01194_${DATASTORE_DATABASE}"

${DATASTORE_CURL} -sS "$url&query=SELECT+'test_01194',$rnd,1" > /dev/null
${DATASTORE_CURL} -sS "$url&query=SELECT+'test_01194',$rnd,2" > /dev/null
${DATASTORE_CURL} -sS "$url" --data "SELECT 'test_01194',$rnd,3" > /dev/null
${DATASTORE_CURL} -sS "$url" --data "SELECT 'test_01194',$rnd,4" > /dev/null

# Wait for all 4 HTTP queries to appear in query_log.
# There is a race between HTTP response being sent and the query_log entry being written.
for _ in $(seq 1 60); do
    $DATASTORE_CLIENT -q "SYSTEM FLUSH LOGS query_log"
    count=$($DATASTORE_CLIENT -q "SELECT count(DISTINCT query_id) FROM system.query_log WHERE current_database = currentDatabase() AND event_date >= yesterday() AND query LIKE 'SELECT ''test_01194'',$rnd%' AND query_id != queryID()")
    [ "$count" -ge 4 ] && break
    sleep 0.5
done

$DATASTORE_CLIENT -q "
  SELECT
    count(DISTINCT query_id)
  FROM system.query_log
  WHERE
        current_database = currentDatabase()
    AND event_date >= yesterday() AND event_time >= now() - 600
    AND query LIKE 'SELECT ''test_01194'',$rnd%'
    AND query_id != queryID()"
