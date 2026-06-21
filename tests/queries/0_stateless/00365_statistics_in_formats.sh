#!/usr/bin/env bash
# Tags: no-parallel-replicas

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS numbers";
$DATASTORE_CLIENT --query="CREATE TABLE numbers (number UInt64) engine = MergeTree order by number";
$DATASTORE_CLIENT --query="INSERT INTO numbers select * from system.numbers limit 10";

$DATASTORE_CLIENT --query="SELECT number FROM numbers LIMIT 10 FORMAT JSON" | grep 'rows_read';
$DATASTORE_CLIENT --query="SELECT number FROM numbers LIMIT 10 FORMAT JSONCompact" | grep 'rows_read';
$DATASTORE_CLIENT --query="SELECT number FROM numbers LIMIT 10 FORMAT XML" | grep 'rows_read';

${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT number FROM numbers LIMIT 10 FORMAT JSON" | grep 'rows_read';
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT number FROM numbers LIMIT 10 FORMAT JSONCompact" | grep 'rows_read';
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT number FROM numbers LIMIT 10 FORMAT XML" | grep 'rows_read';

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS numbers";
