#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "CREATE TABLE t_async_insert_deadlock (a UInt64) ENGINE = Log"

echo '{"a": 1}' | $DATASTORE_CLIENT --async_insert 1 --wait_for_async_insert 1 --query "INSERT INTO t_async_insert_deadlock FORMAT JSONEachRow"

$DATASTORE_CLIENT --query "SELECT * FROM t_async_insert_deadlock ORDER BY a"
$DATASTORE_CLIENT --query "DROP TABLE t_async_insert_deadlock"
