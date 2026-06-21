#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t_json_async_insert"
$DATASTORE_CLIENT --enable_json_type=1 -q "CREATE TABLE t_json_async_insert (data JSON) ENGINE = MergeTree ORDER BY tuple()"

$DATASTORE_CLIENT --async_insert=1 --wait_for_async_insert=1 -q 'INSERT INTO t_json_async_insert FORMAT JSONAsObject {"aaa"}' 2>&1 | grep -o -m1 "INCORRECT_DATA"
$DATASTORE_CLIENT -q "SELECT count() FROM t_json_async_insert"
$DATASTORE_CLIENT -q "SELECT count() FROM system.parts WHERE database = '$DATASTORE_DATABASE' AND table = 't_json_async_insert'"

$DATASTORE_CLIENT --async_insert=1 --wait_for_async_insert=1 -q 'INSERT INTO t_json_async_insert FORMAT JSONAsObject {"aaa"}' 2>&1 | grep -o -m1 "INCORRECT_DATA" &
$DATASTORE_CLIENT --async_insert=1 --wait_for_async_insert=1 -q 'INSERT INTO t_json_async_insert FORMAT JSONAsObject {"k1": "aaa"}' &

wait

$DATASTORE_CLIENT -q "SELECT data.k1 FROM t_json_async_insert ORDER BY data.k1" --allow_suspicious_types_in_order_by 1
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t_json_async_insert"
