#!/usr/bin/env bash
# Tags: no-fasttest

# Regression test for https://github.com/ClickHouse/Datastore/issues/86330
# ALTER TABLE ... MODIFY COLUMN ... REMOVE SETTINGS on an Iceberg table
# should return an error instead of causing a segfault.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

TABLE="t_${DATASTORE_DATABASE}_${RANDOM}"
TABLE_PATH="${USER_FILES_PATH}/${TABLE}/"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS ${TABLE}"
${DATASTORE_CLIENT} --query "
    CREATE TABLE ${TABLE} (c0 Int)
    ENGINE = IcebergLocal('${TABLE_PATH}')
"
# To have at least one real snapshot. Otherwise alter can be noop.
${DATASTORE_CLIENT} --allow_insert_into_iceberg=1 --query "INSERT INTO ${TABLE} VALUES (1)"

${DATASTORE_CLIENT} --query "
    ALTER TABLE ${TABLE} MODIFY COLUMN c0 REMOVE SETTINGS
" 2>&1 | grep -o -m1 "NOT_IMPLEMENTED"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS ${TABLE}"
rm -rf "${TABLE_PATH}"
