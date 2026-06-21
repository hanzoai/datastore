#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

local_dir="${DATASTORE_TMP}/clone_as_cross_db_$$"

$DATASTORE_LOCAL --path "$local_dir" --query "
    CREATE DATABASE ${DATASTORE_DATABASE_1};
    CREATE TABLE ${DATASTORE_DATABASE_1}.source_tbl (x Int8, y String) ENGINE = MergeTree PRIMARY KEY x;
    INSERT INTO ${DATASTORE_DATABASE_1}.source_tbl VALUES (1, 'a'), (2, 'b'), (3, 'c');
    CREATE TABLE default.clone_target CLONE AS ${DATASTORE_DATABASE_1}.source_tbl;
    SELECT * FROM default.clone_target ORDER BY x;
"

rm -rf "$local_dir"
