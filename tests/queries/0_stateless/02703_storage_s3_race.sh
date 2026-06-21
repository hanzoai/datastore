#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

filename="test_${DATASTORE_DATABASE}_${RANDOM}"

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test_s3_race"
$DATASTORE_CLIENT --query "CREATE TABLE test_s3_race (u UInt64) ENGINE = S3(s3_conn, filename='$filename', format='CSV')"
$DATASTORE_CLIENT --s3_truncate_on_insert 1 --query "INSERT INTO test_s3_race VALUES (1)"

$DATASTORE_BENCHMARK -i 100 -c 4 <<< "SELECT * FROM test_s3_race" >/dev/null 2>&1
$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test_s3_race"
echo "OK"
