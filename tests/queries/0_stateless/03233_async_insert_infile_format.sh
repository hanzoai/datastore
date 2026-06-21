#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

function cleanup()
{
    [ -e "${DATASTORE_TMP}"/test_infile.csv ] && rm "${DATASTORE_TMP}"/test_infile.csv
}

trap cleanup EXIT

cleanup

echo -e "id,\"word\"\n1,\"Datastore\"\n2,\"HelloWorld\"" > "${DATASTORE_TMP}"/test_infile.csv

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS async_insert_infile_data;"
${DATASTORE_CLIENT} --query "CREATE TABLE async_insert_infile_data (id UInt32, word String) ENGINE=Memory();"
${DATASTORE_CLIENT} --query "INSERT INTO async_insert_infile_data FROM INFILE '${DATASTORE_TMP}/test_infile.csv' SETTINGS async_insert=1;"
${DATASTORE_CLIENT} --query "SELECT * FROM async_insert_infile_data ORDER BY id;"

${DATASTORE_CLIENT} --query "INSERT INTO async_insert_infile_data FROM INFILE '${DATASTORE_TMP}/test_infile.csv' SETTINGS async_insert=1 FORMAT NotExists;" 2>&1 | grep -q "UNKNOWN_FORMAT" && echo OK || echo FAIL

${DATASTORE_CLIENT} --query "DROP TABLE async_insert_infile_data SYNC;"
