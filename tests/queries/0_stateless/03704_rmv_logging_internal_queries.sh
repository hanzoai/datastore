#!/usr/bin/env bash
# Tags: atomic-database

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Test that some internal queries from refreshable materialized views are logged correctly

$DATASTORE_CLIENT --query "CREATE VIEW one_proxy AS SELECT * FROM system.one"
$DATASTORE_CLIENT --query "
CREATE MATERIALIZED VIEW rmv_test
REFRESH AFTER 1 HOUR
(
    dummy UInt8
)
ENGINE = MergeTree
ORDER BY dummy
EMPTY
AS SELECT
    dummy
FROM one_proxy"
$DATASTORE_CLIENT --query "SYSTEM REFRESH VIEW rmv_test"
$DATASTORE_CLIENT --query "SYSTEM WAIT VIEW rmv_test"

# refresh with the source table absent to verify that exceptions are logged, too
$DATASTORE_CLIENT --query "DROP VIEW one_proxy"
$DATASTORE_CLIENT --query "SYSTEM REFRESH VIEW rmv_test"
$DATASTORE_CLIENT --query "SYSTEM WAIT VIEW rmv_test" 2> /dev/null

$DATASTORE_CLIENT --query "SYSTEM FLUSH LOGS query_log"
$DATASTORE_CLIENT --query "
SELECT
    countIf(query LIKE '%INSERT INTO $DATASTORE_DATABASE.\`.tmp.inner_id.%' AND type = 'QueryStart') > 0,
    countIf(query LIKE '%INSERT INTO $DATASTORE_DATABASE.\`.tmp.inner_id.%' AND type = 'QueryFinish') > 0,
    countIf(query = '(create target table)' AND type = 'ExceptionBeforeStart') > 0
FROM system.query_log
WHERE event_date >= yesterday() AND event_time >= now() - 600 AND is_internal = 1 AND current_database IN [currentDatabase(), 'default']
"

$DATASTORE_CLIENT --query "DROP VIEW rmv_test"
