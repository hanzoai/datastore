#!/usr/bin/env bash
# Tags: no-fasttest, use-rocksdb

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS rocksdb_with_filter;"

$DATASTORE_CLIENT --query="CREATE TABLE rocksdb_with_filter (key String, value String) ENGINE=EmbeddedRocksDB PRIMARY KEY key;"
$DATASTORE_CLIENT --query="INSERT INTO rocksdb_with_filter (*) SELECT n.number, n.number*10 FROM numbers(10000) n;"

$DATASTORE_CLIENT --query "EXPLAIN actions=1 SELECT value FROM rocksdb_with_filter LIMIT 1" | grep -A 2 "ReadFromEmbeddedRocksDB"
$DATASTORE_CLIENT --query "EXPLAIN actions=1,optimize=0 SELECT value FROM rocksdb_with_filter" | grep -A 2 "ReadFromEmbeddedRocksDB" | tr -d "[:blank:]"

$DATASTORE_CLIENT --query "SELECT count() FROM rocksdb_with_filter WHERE key = '5000'"
$DATASTORE_CLIENT --query "SELECT value FROM rocksdb_with_filter WHERE key = '5000' FORMAT JSON" | grep "rows_read" | tr -d "[:blank:]"
$DATASTORE_CLIENT --query "EXPLAIN actions=1 SELECT value FROM rocksdb_with_filter WHERE key = '5000'" | grep -A 3 "ReadFromEmbeddedRocksDB"

$DATASTORE_CLIENT --query "SELECT count() FROM rocksdb_with_filter WHERE key = '5000' OR key = '6000'"
$DATASTORE_CLIENT --query "SELECT value FROM rocksdb_with_filter WHERE key = '5000' OR key = '6000' FORMAT JSON" | grep "rows_read" | tr -d "[:blank:]"

$DATASTORE_CLIENT "--param_key=5000" --query "SELECT count() FROM rocksdb_with_filter WHERE key = {key:String}"
$DATASTORE_CLIENT "--param_key=5000" --query "SELECT value FROM rocksdb_with_filter WHERE key = {key:String} FORMAT JSON" | grep "rows_read" | tr -d "[:blank:]"

$DATASTORE_CLIENT --query "SELECT count() FROM rocksdb_with_filter WHERE key IN ('5000', '6000')"
$DATASTORE_CLIENT --query "SELECT value FROM rocksdb_with_filter WHERE key IN ('5000', '6000') FORMAT JSON" | grep "rows_read" | tr -d "[:blank:]"

$DATASTORE_CLIENT --query="DROP TABLE rocksdb_with_filter;"
