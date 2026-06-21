#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo 'DROP TABLE IF EXISTS bom' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo 'CREATE TABLE bom (a UInt8, b UInt8, c UInt8) ENGINE = Memory' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo -ne '1,2,3\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+bom+FORMAT+CSV" --data-binary @-
echo -ne '\xEF\xBB\xBF4,5,6\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+bom+FORMAT+CSV" --data-binary @-
echo 'SELECT * FROM bom ORDER BY a' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo 'DROP TABLE bom' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
