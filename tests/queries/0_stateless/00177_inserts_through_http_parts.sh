#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TABLE" -d 'IF EXISTS insert'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=CREATE" -d 'TABLE insert (x UInt8) ENGINE = Memory'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'INSERT INTO insert VALUES (1),(2)'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+insert+VALUES" -d '(3),(4)'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+insert" -d 'VALUES (5),(6)'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+insert+VALUES+(7)" -d ',(8)'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+insert+VALUES+(9),(10)" -d ' '
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'SELECT x FROM insert ORDER BY x'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TABLE" -d 'insert'
