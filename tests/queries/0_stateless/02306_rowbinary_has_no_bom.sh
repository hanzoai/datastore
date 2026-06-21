#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo "DROP TABLE IF EXISTS table_with_uint64" | ${DATASTORE_CURL} -d@- -sS "${DATASTORE_URL}"
echo "CREATE TABLE table_with_uint64(no UInt64) ENGINE = MergeTree ORDER BY no" | ${DATASTORE_CURL} -d@- -sS "${DATASTORE_URL}"
echo -en '\xef\xbb\xbf\x00\xab\x3b\xec\x16' | ${DATASTORE_CURL} --data-binary @- "${DATASTORE_URL}&query=INSERT+INTO+table_with_uint64(no)+FORMAT+RowBinary"
echo "SELECT * FROM table_with_uint64" | ${DATASTORE_CURL} -d@- -sS "${DATASTORE_URL}"
