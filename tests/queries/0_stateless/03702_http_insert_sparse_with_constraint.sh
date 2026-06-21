#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo 'DROP TABLE IF EXISTS 03702_data'                       | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'CREATE TABLE 03702_data
      (c Bool)
      ENGINE = MergeTree
      ORDER BY c
      SETTINGS ratio_of_defaults_for_sparse_serialization=0' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
# Inserting one row with default value to make the column sparse
echo 'INSERT INTO 03702_data SELECT false'                   | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
# Adding constraint
echo 'ALTER TABLE 03702_data ADD CONSTRAINT check_c CHECK c' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
# Inserting another row that should pass constraint check
echo 'INSERT INTO 03702_data FORMAT CSV true'                | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'SELECT * FROM 03702_data ORDER BY c'                   | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
