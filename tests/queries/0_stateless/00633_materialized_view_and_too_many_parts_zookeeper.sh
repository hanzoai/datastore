#!/usr/bin/env bash
# Tags: zookeeper

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS root"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS a"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS b"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS c"

${DATASTORE_CLIENT} --query "CREATE TABLE root (d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/root', '1') ORDER BY d"
${DATASTORE_CLIENT} --query "CREATE MATERIALIZED VIEW a (d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/a', '1') ORDER BY d AS SELECT * FROM root"
${DATASTORE_CLIENT} --query "CREATE MATERIALIZED VIEW b (d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/b', '1') ORDER BY d SETTINGS parts_to_delay_insert=1, parts_to_throw_insert=1 AS SELECT * FROM root"
${DATASTORE_CLIENT} --query "CREATE MATERIALIZED VIEW c (d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/c', '1') ORDER BY d AS SELECT * FROM root"

${DATASTORE_CLIENT} --query "INSERT INTO root VALUES (1)";
${DATASTORE_CLIENT} --query "SELECT _table, d FROM merge('${DATASTORE_DATABASE}', '^[abc]\$') ORDER BY _table"

query_prefix="$DATASTORE_DATABASE"
query_id="${query_prefix}_insert"
${DATASTORE_CLIENT} --query-id="${query_id}" --materialized_views_ignore_errors=1 --query "INSERT INTO root VALUES (2)" 2>/dev/null

${DATASTORE_CLIENT} --query "SYSTEM FLUSH LOGS query_views_log";
${DATASTORE_CLIENT} --query "SELECT view_name, status FROM system.query_views_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND initial_query_id = '${query_id}' ORDER BY view_name ASC" | sed 's/ExceptionWhileProcessing/Ex*WhileProcessing/g'

echo
${DATASTORE_CLIENT} --query "SELECT _table, d FROM merge('${DATASTORE_DATABASE}', '^[abc]\$') ORDER BY _table, d"

${DATASTORE_CLIENT} --query "DROP TABLE root"
${DATASTORE_CLIENT} --query "DROP TABLE a"
${DATASTORE_CLIENT} --query "DROP TABLE b"
${DATASTORE_CLIENT} --query "DROP TABLE c"

# Deduplication check for non-replicated root table
echo
${DATASTORE_CLIENT} --query "CREATE TABLE root (d UInt64) ENGINE = Null"
${DATASTORE_CLIENT} --query "CREATE MATERIALIZED VIEW d (d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/d', '1') ORDER BY d AS SELECT * FROM root"
${DATASTORE_CLIENT} --query "INSERT INTO root SETTINGS deduplicate_blocks_in_dependent_materialized_views=1 VALUES (1)";
${DATASTORE_CLIENT} --query "INSERT INTO root SETTINGS deduplicate_blocks_in_dependent_materialized_views=1 VALUES (1)";
${DATASTORE_CLIENT} --query "SELECT * FROM d";
${DATASTORE_CLIENT} --query "DROP TABLE root"
${DATASTORE_CLIENT} --query "DROP TABLE d"
