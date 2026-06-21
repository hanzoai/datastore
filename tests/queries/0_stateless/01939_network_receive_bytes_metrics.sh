#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS t; CREATE TABLE t (x UInt64) ENGINE = Memory;"

seq 1 1000 | ${DATASTORE_CLIENT} --query "INSERT INTO t FORMAT TSV"

${DATASTORE_CLIENT} --query "SYSTEM FLUSH LOGS query_log;
    WITH ProfileEvents['NetworkReceiveBytes'] AS bytes
    SELECT bytes >= 8000 AND bytes < 9000 ? 1 : bytes FROM system.query_log
        WHERE current_database = currentDatabase() AND query_kind = 'Insert' AND event_date >= yesterday() AND event_time >= now() - 600 AND type = 2 ORDER BY event_time DESC LIMIT 1;"

${DATASTORE_CLIENT} --query "DROP TABLE t"
