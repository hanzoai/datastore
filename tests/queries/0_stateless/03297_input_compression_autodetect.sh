#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

DATASTORE_CLIENT="${DATASTORE_CLIENT} --optimize_trivial_insert_select=0"

$DATASTORE_LOCAL --query "SELECT number FROM numbers(10)" > "${DATASTORE_TMP}/numbers.jsonl.gz"
$DATASTORE_LOCAL --query "SELECT * FROM table" < "${DATASTORE_TMP}/numbers.jsonl.gz"
$DATASTORE_LOCAL --query "SELECT * FROM table" < "${DATASTORE_TMP}/numbers.jsonl.gz" > "${DATASTORE_TMP}/numbers.csv.bz2"
$DATASTORE_LOCAL --copy < "${DATASTORE_TMP}/numbers.csv.bz2" > "${DATASTORE_TMP}/numbers.parquet"
$DATASTORE_LOCAL --copy < "${DATASTORE_TMP}/numbers.parquet"

echo '---'

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT --query "CREATE TABLE test (number UInt64) ENGINE = Memory"
$DATASTORE_CLIENT --query "INSERT INTO test FORMAT JSONLines" < "${DATASTORE_TMP}/numbers.jsonl.gz"
$DATASTORE_CLIENT --query "INSERT INTO test FORMAT CSV" < "${DATASTORE_TMP}/numbers.csv.bz2"
$DATASTORE_CLIENT --query "INSERT INTO test SELECT c1 FROM input() FORMAT Parquet" < "${DATASTORE_TMP}/numbers.parquet"
$DATASTORE_CLIENT --query "SELECT * FROM test"
$DATASTORE_CLIENT --query "DROP TABLE test"
