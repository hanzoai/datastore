#!/usr/bin/env bash
# Tags: no-parallel

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP DATABASE IF EXISTS test_db";

${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "CREATE DATABASE {db:Identifier}";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "CREATE TABLE {db:Identifier}.{tbl:Identifier} (id UInt64, col1 UInt64) ENGINE = MergeTree() ORDER BY id";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "INSERT INTO {db:Identifier}.{tbl:Identifier} VALUES (1,2)";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "SELECT * FROM {db:Identifier}.{tbl:Identifier}";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "OPTIMIZE TABLE {db:Identifier}.{tbl:Identifier}";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "ALTER TABLE {db:Identifier}.{tbl:Identifier} RENAME COLUMN col1 to col2";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "EXISTS TABLE {db:Identifier}.{tbl:Identifier}";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "INSERT INTO {db:Identifier}.{tbl:Identifier} VALUES (3,4)";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "SELECT col2 FROM {db:Identifier}.{tbl:Identifier} ORDER BY col2 DESC";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "DROP TABLE {db:Identifier}.{tbl:Identifier}";
${DATASTORE_CLIENT} --param_db="test_db" --param_tbl="test_t" --query "DROP DATABASE {db:Identifier}";
