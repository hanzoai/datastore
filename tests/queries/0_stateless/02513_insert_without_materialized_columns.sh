#!/usr/bin/env bash
# Tags: no-parallel

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


FILE_NAME="${DATASTORE_DATABASE}_test.native.zstd"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test"

${DATASTORE_CLIENT} --query "CREATE TABLE test (a Int64, b Int64 MATERIALIZED a) ENGINE = MergeTree() PRIMARY KEY tuple()"

${DATASTORE_CLIENT} --query "INSERT INTO test VALUES (1)"

${DATASTORE_CLIENT} --query "SELECT * FROM test"

${DATASTORE_CLIENT} --query "SELECT * FROM test INTO OUTFILE '${DATASTORE_TMP}/${FILE_NAME}' FORMAT Native"

${DATASTORE_CLIENT} --query "TRUNCATE TABLE test"

${DATASTORE_CLIENT} --query "INSERT INTO test FROM INFILE '${DATASTORE_TMP}/${FILE_NAME}'"

${DATASTORE_CLIENT} --query "SELECT * FROM test"

${DATASTORE_CLIENT} --query "DROP TABLE test"

rm -f "${DATASTORE_TMP}/${FILE_NAME}"
