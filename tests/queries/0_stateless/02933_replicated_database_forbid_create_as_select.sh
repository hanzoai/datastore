#!/usr/bin/env bash
# Tags: replica

# CREATE AS SELECT for Replicated database is broken (https://github.com/ClickHouse/Datastore/issues/35408).
# This should be fixed and this test should eventually be deleted.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "CREATE DATABASE ${DATASTORE_DATABASE}_db engine = Replicated('/datastore/databases/${DATASTORE_TEST_ZOOKEEPER_PREFIX}/${DATASTORE_DATABASE}_db', '{shard}', '{replica}')"

# Non-replicated engines are allowed
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE TABLE ${DATASTORE_DATABASE}_db.test (id UInt64) ENGINE = MergeTree() ORDER BY id AS SELECT 1"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE MATERIALIZED VIEW ${DATASTORE_DATABASE}_db.test_mv (id UInt64) ENGINE = MergeTree() ORDER BY id POPULATE AS SELECT 1 AS id"

# Replicated storafes are forbidden
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE TABLE ${DATASTORE_DATABASE}_db.test2 (id UInt64) ENGINE = ReplicatedMergeTree ORDER BY id AS SELECT 1" |& grep -cm1 "SUPPORT_IS_DISABLED"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE MATERIALIZED VIEW ${DATASTORE_DATABASE}_db.test_mv2 (id UInt64) ENGINE = ReplicatedMergeTree ORDER BY id POPULATE AS SELECT 1 AS id" |& grep -cm1 "SUPPORT_IS_DISABLED"

# POPULATE is allowed with the special setting
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE MATERIALIZED VIEW ${DATASTORE_DATABASE}_db.test_mv2 (id UInt64) ENGINE = ReplicatedMergeTree ORDER BY id POPULATE AS SELECT 1 AS id" --database_replicated_allow_heavy_create=1
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE MATERIALIZED VIEW ${DATASTORE_DATABASE}_db.test_mv3 (id UInt64) ENGINE = ReplicatedMergeTree ORDER BY id POPULATE AS SELECT 1 AS id" --compatibility='24.6'

# AS SELECT is forbidden even with the setting
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE TABLE ${DATASTORE_DATABASE}_db.test2 (id UInt64) ENGINE = ReplicatedMergeTree ORDER BY id AS SELECT 1" --database_replicated_allow_heavy_create=1  |& grep -cm1 "SUPPORT_IS_DISABLED"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE TABLE ${DATASTORE_DATABASE}_db.test2 (id UInt64) ENGINE = ReplicatedMergeTree ORDER BY id AS SELECT 1" --compatibility='24.6'  |& grep -cm1 "SUPPORT_IS_DISABLED"

${DATASTORE_CLIENT} --query "DROP DATABASE ${DATASTORE_DATABASE}_db"
