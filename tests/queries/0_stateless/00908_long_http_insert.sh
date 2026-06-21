#!/usr/bin/env bash
# Tags: long

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo 'DROP TABLE IF EXISTS table_for_insert'                            | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'CREATE TABLE table_for_insert (a UInt8, b UInt8) ENGINE = Memory' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo "INSERT INTO table_for_insert VALUES $(printf '%*s' "1000000" "" | sed 's/ /(1, 2)/g')" | ${DATASTORE_CURL_COMMAND} -q --max-time 30 -sSg "${DATASTORE_URL}" -d @-
echo 'SELECT count(*) FROM table_for_insert'                            | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'DROP TABLE IF EXISTS table_for_insert'                            | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
