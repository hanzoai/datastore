#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

WORKING_FOLDER="${USER_FILES_PATH}/${DATASTORE_DATABASE}"
rm -rf "${WORKING_FOLDER}"
mkdir "${WORKING_FOLDER}"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_async_insert"
${DATASTORE_CLIENT} --query "CREATE TABLE test_async_insert (a String) Engine = MergeTree() ORDER BY ()"
${DATASTORE_CLIENT} --query "SELECT cast(if(number < 65000,'x', randomString(10)) as String) FROM numbers(140000) INTO OUTFILE '${WORKING_FOLDER}/data.datastore' FORMAT rowBinary"
${DATASTORE_CLIENT} --query "SET async_insert = 1; set async_insert_max_data_size = 660000; INSERT INTO test_async_insert FROM INFILE '${WORKING_FOLDER}/data.datastore' FORMAT rowBinary"
${DATASTORE_CLIENT} --query "SELECT count(*) FROM test_async_insert"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_async_insert" 
