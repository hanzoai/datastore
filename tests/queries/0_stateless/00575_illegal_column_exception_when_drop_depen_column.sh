#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


exception_pattern="Code: 44.*Cannot drop column \`id\`, because column \`id2\` depends on it"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_00575;"
${DATASTORE_CLIENT} --allow_deprecated_syntax_for_merge_tree=1 --query "CREATE TABLE test_00575 (dt Date DEFAULT now(), id UInt32, id2 UInt32 DEFAULT id + 1) ENGINE = MergeTree(dt, dt, 8192);"
${DATASTORE_CLIENT} --query "INSERT INTO test_00575(dt,id) VALUES ('2018-02-22',3), ('2018-02-22',4), ('2018-02-22',5);"
${DATASTORE_CLIENT} --query "SELECT * FROM test_00575 ORDER BY id;"
echo "$(${DATASTORE_CLIENT} --query "ALTER TABLE test_00575 DROP COLUMN id;" --server_logs_file=/dev/null 2>&1 | grep -c "$exception_pattern")"
${DATASTORE_CLIENT} --query "ALTER TABLE test_00575 DROP COLUMN id2;"
${DATASTORE_CLIENT} --query "SELECT * FROM test_00575 ORDER BY id;"
${DATASTORE_CLIENT} --query "ALTER TABLE test_00575 DROP COLUMN id;"
${DATASTORE_CLIENT} --query "SELECT * FROM test_00575 ORDER BY dt"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_00575;"
