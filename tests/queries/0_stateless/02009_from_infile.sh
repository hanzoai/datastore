#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

[ -e "${DATASTORE_TMP}"/test_infile.gz ] && rm "${DATASTORE_TMP}"/test_infile.gz
[ -e "${DATASTORE_TMP}"/test_infile ] && rm "${DATASTORE_TMP}"/test_infile

echo "Hello" > "${DATASTORE_TMP}"/test_infile

gzip "${DATASTORE_TMP}"/test_infile

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_infile;"
${DATASTORE_CLIENT} --query "CREATE TABLE test_infile (word String) ENGINE=Memory();"
${DATASTORE_CLIENT} --query "INSERT INTO test_infile FROM INFILE '${DATASTORE_TMP}/test_infile.gz' FORMAT CSV;"
${DATASTORE_CLIENT} --query "SELECT * FROM test_infile;"

# if it not fails, select will print information
${DATASTORE_LOCAL} --query "CREATE TABLE test_infile (word String) ENGINE=Memory(); INSERT INTO test_infile FROM INFILE '${DATASTORE_TMP}/test_infile.gz' FORMAT CSV; SELECT * from test_infile;"

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TABLE" -d 'IF EXISTS test_infile_url'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=CREATE" -d 'TABLE test_infile_url (x String) ENGINE = Memory'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "INSERT INTO test_infile_url FROM INFILE '${DATASTORE_TMP}/test_infile.gz' FORMAT CSV" 2>&1 | grep -q "UNKNOWN_TYPE_OF_QUERY" && echo "Correct URL" || echo 'Fail'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'SELECT x FROM test_infile_url'
${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=DROP+TABLE" -d 'test_infile_url'
