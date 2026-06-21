#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_00687;"

${DATASTORE_CLIENT} --query "CREATE TABLE test_00687(val Int64) engine = Memory;"

${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (1);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (2);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (3);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (4);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (5);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (6);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (7);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (8);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00687 VALUES (9);"

${DATASTORE_CLIENT} --query "SELECT TOP 2 * FROM test_00687 ORDER BY val;"
${DATASTORE_CLIENT} --query "SELECT TOP (2) * FROM test_00687 ORDER BY val;"
${DATASTORE_CLIENT} --query "SELECT * FROM test_00687 ORDER BY val LIMIT 2 OFFSET 2;"

echo "$(${DATASTORE_CLIENT} --query "SELECT TOP 2 * FROM test_00687 ORDER BY val LIMIT 2;" 2>&1 | grep -c "Code: 406")"
echo "$(${DATASTORE_CLIENT} --query "SELECT * FROM test_00687 ORDER BY val LIMIT 2,3 OFFSET 2;" 2>&1 | grep -c "Code: 62")"

${DATASTORE_CLIENT} --query "DROP TABLE test_00687;"
