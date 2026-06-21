#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'DROP TABLE IF EXISTS bad_arrays'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'CREATE TABLE bad_arrays (a Array(String)) ENGINE = Memory'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "INSERT INTO bad_arrays VALUES ([123]), (['123', concat('Hello', ' world!'), toString(123)])"
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'SELECT * FROM bad_arrays ORDER BY a'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'DROP TABLE bad_arrays'
