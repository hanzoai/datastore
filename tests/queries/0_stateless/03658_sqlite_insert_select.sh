#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

rm -f "${DATASTORE_TMP}/database.sqlite3" "${DATASTORE_TMP}/test.json"

sqlite3 "${DATASTORE_TMP}/database.sqlite3" 'CREATE TABLE _kv(k TEXT, v TEXT, PRIMARY KEY (k));'
echo '{"max_ts":123456}' > "${DATASTORE_TMP}/test.json"

${DATASTORE_LOCAL} --query="
CREATE DATABASE ${DATASTORE_DATABASE_1} ENGINE = SQLite('${DATASTORE_TMP}/database.sqlite3');
INSERT INTO ${DATASTORE_DATABASE_1}._kv VALUES ('a', 'b');
SELECT 'max_ts' AS k, CAST(max_ts, 'String') AS v FROM file('${DATASTORE_TMP}/test.json');
INSERT INTO ${DATASTORE_DATABASE_1}._kv SELECT 'max_ts' AS k, CAST(max_ts, 'String') AS v from file('${DATASTORE_TMP}/test.json');
SELECT * FROM ${DATASTORE_DATABASE_1}._kv ORDER BY ALL;
"

rm "${DATASTORE_TMP}/database.sqlite3" "${DATASTORE_TMP}/test.json"
