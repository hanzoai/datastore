#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'SELECT 1' --referer 'https://meta.ua/'
# Wait for the HTTP query to appear in query_log.
# There is a race between HTTP response being sent and the query_log entry being written.
for _ in $(seq 1 60); do
    ${DATASTORE_CLIENT} --query "SYSTEM FLUSH LOGS query_log"
    count=$(${DATASTORE_CLIENT} --query "SELECT count() FROM system.query_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND current_database = currentDatabase() AND http_referer LIKE '%meta%'")
    [ "$count" -ge 1 ] && break
    sleep 0.5
done
${DATASTORE_CLIENT} --query "SELECT http_referer FROM system.query_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND current_database = currentDatabase() AND http_referer LIKE '%meta%' LIMIT 1"
