#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "insert into table function file(data.jsonl, 'JSONEachRow', 'x UInt32 default 42, y String') select number as x, 'String' as y from numbers(10)"

$DATASTORE_CLIENT -q "drop table if exists test"
$DATASTORE_CLIENT -q "create table test engine=File(JSONEachRow, 'data.jsonl')"
$DATASTORE_CLIENT -q "show create table test"
$DATASTORE_CLIENT -q "detach table test"

rm $USER_FILES_PATH/data.jsonl

$DATASTORE_CLIENT -q "attach table test"
$DATASTORE_CLIENT -q "select * from test" 2>&1 | grep -q "FILE_DOESNT_EXIST" && echo "OK" || echo "FAIL"


$DATASTORE_CLIENT -q "drop table test"
$DATASTORE_CLIENT -q "create table test (x UInt64) engine=Memory()"

$DATASTORE_CLIENT -q "drop table if exists test_dist"
$DATASTORE_CLIENT -q "create table test_dist engine=Distributed('test_shard_localhost', currentDatabase(), 'test')"

$DATASTORE_CLIENT -q "detach table test_dist"
$DATASTORE_CLIENT -q "drop table test"
$DATASTORE_CLIENT -q "attach table test_dist"
$DATASTORE_CLIENT --prefer_localhost_replica=1 -q "select * from test_dist" 2>&1 | grep -q "UNKNOWN_TABLE" && echo "OK" || echo "FAIL"
