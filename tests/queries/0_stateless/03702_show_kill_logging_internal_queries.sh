#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Test that internal queries are logged correctly

$DATASTORE_CLIENT --query "SHOW TABLES FORMAT Null"
$DATASTORE_CLIENT --query "SHOW ENGINES FORMAT Null"
$DATASTORE_CLIENT --query "SHOW FUNCTIONS LIKE 'plus' FORMAT Null"
$DATASTORE_CLIENT --query "SHOW SETTING max_threads FORMAT Null"
$DATASTORE_CLIENT --query "KILL QUERY WHERE query_id = 'nonexistent' SYNC" &>/dev/null

$DATASTORE_CLIENT --query "SYSTEM FLUSH LOGS query_log"

$DATASTORE_CLIENT --query "
SELECT
    countIf(query LIKE '%system.tables%' AND type = 'QueryStart'),
    countIf(query LIKE '%system.tables%' AND type = 'QueryFinish'),
    countIf(query LIKE '%system.table_engines%' AND type = 'QueryStart'),
    countIf(query LIKE '%system.table_engines%' AND type = 'QueryFinish'),
    countIf(query LIKE '%system.functions%' AND type = 'QueryStart'),
    countIf(query LIKE '%system.functions%' AND type = 'QueryFinish'),
    countIf(query LIKE '%system.settings%' AND type = 'QueryStart'),
    countIf(query LIKE '%system.settings%' AND type = 'QueryFinish'),
    countIf(query LIKE '%system.processes%' AND type = 'QueryStart'),
    countIf(query LIKE '%system.processes%' AND type = 'QueryFinish')
FROM system.query_log
WHERE event_date >= yesterday() AND event_time >= now() - 600 AND is_internal = 1 AND current_database = currentDatabase()"
