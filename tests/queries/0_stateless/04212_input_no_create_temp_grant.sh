#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

set -e

user="user_${DATASTORE_TEST_UNIQUE_NAME}"
table="t_${DATASTORE_TEST_UNIQUE_NAME}"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS ${user}"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS ${table}"

${DATASTORE_CLIENT} --query "CREATE USER ${user} IDENTIFIED WITH PLAINTEXT_PASSWORD BY 'hello'"
${DATASTORE_CLIENT} --query "CREATE TABLE ${table} (a UInt32, b String) ENGINE = Memory"
${DATASTORE_CLIENT} --query "GRANT INSERT, SELECT ON ${DATASTORE_DATABASE}.${table} TO ${user}"

# `input` must work without the `CREATE TEMPORARY TABLE` grant: it does not create a temporary table,
# it only reads the data stream attached to the INSERT query.
${DATASTORE_CLIENT} --query "SELECT number::UInt32 AS a, 'val' AS b FROM numbers(3) FORMAT Native" | \
    ${DATASTORE_CURL} -sS \
        "${DATASTORE_URL}&user=${user}&password=hello&query=INSERT+INTO+${DATASTORE_DATABASE}.${table}+SELECT+*+FROM+input(%27a+UInt32%2C+b+String%27)+FORMAT+Native" \
        --data-binary @-

${DATASTORE_CLIENT} --user "${user}" --password hello --query "SELECT * FROM ${DATASTORE_DATABASE}.${table} ORDER BY a"

${DATASTORE_CLIENT} --query "DROP TABLE ${table}"
${DATASTORE_CLIENT} --query "DROP USER ${user}"
