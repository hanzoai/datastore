#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

[ ! -z "$DATASTORE_CLIENT_REDEFINED" ] && DATASTORE_CLIENT=$DATASTORE_CLIENT_REDEFINED

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS x;"
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS y;"
$DATASTORE_CLIENT -q "CREATE TABLE x(i int) ENGINE MergeTree ORDER BY i;"
$DATASTORE_CLIENT -q "RENAME TABLE x TO y;"

DATASTORE_CLIENT_WITH_LOG=$(echo ${DATASTORE_CLIENT} | sed 's/'"--send_logs_level=${DATASTORE_CLIENT_SERVER_LOGS_LEVEL}"'/--send_logs_level=trace/g')
regexp="${DATASTORE_DATABASE}\\.x" # Check if there are still log entries with old table name
$DATASTORE_CLIENT_WITH_LOG --send_logs_source_regexp "$regexp" -q "INSERT INTO y VALUES(1);"

$DATASTORE_CLIENT -q "DROP TABLE y;"
