#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} -m --query "
DROP TABLE IF EXISTS tbl;
CREATE TABLE tbl (a Int32) ENGINE = MergeTree() ORDER BY tuple();
INSERT INTO tbl VALUES (2), (80), (-12345);
"

backup_name="Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}')"

${DATASTORE_CLIENT} --query "BACKUP TABLE tbl TO ${backup_name} FORMAT Null"

${DATASTORE_CLIENT} -m --query "
DROP TABLE tbl;
RESTORE ALL FROM ${backup_name} FORMAT Null
"

${DATASTORE_CLIENT} --query "SELECT * FROM tbl"
