#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --query "
CREATE DATABASE ${DATASTORE_DATABASE_1};
USE ${DATASTORE_DATABASE_1};
CREATE TABLE t (s String) ORDER BY ();
INSERT INTO t VALUES ('Hello, world');
SELECT * FROM t;
"

# We can switch to the previously created database using a command-line argument:

$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --query "SELECT * FROM ${DATASTORE_DATABASE_1}.t;"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --query "USE ${DATASTORE_DATABASE_1}; SELECT * FROM t;"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --database default --query "USE ${DATASTORE_DATABASE_1}; SELECT * FROM t;"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --database ${DATASTORE_DATABASE_1} --query "SELECT * FROM t;"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --database system --query "USE ${DATASTORE_DATABASE_1}; SELECT * FROM t;"

# Only default database is configured as a filesystem overlay:

echo "Hello from a file" > "${DATASTORE_TMP}/file.csv"

$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --query "SELECT * FROM '${DATASTORE_TMP}/file.csv'"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --query "SELECT * FROM default.\`${DATASTORE_TMP}/file.csv\`"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --database ${DATASTORE_DATABASE_1} --query "SELECT * FROM default.\`${DATASTORE_TMP}/file.csv\`"

$DATASTORE_LOCAL --path "${DATASTORE_TMP}" --query "DROP DATABASE ${DATASTORE_DATABASE_1};"
