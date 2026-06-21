#!/usr/bin/env bash
CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT "
    SELECT 'Policy for table \`*\` does not affect other tables in the database';
    CREATE ROW POLICY 02703_asterisk_${DATASTORE_DATABASE}_policy ON ${DATASTORE_DATABASE}.\`*\` USING x=1 AS permissive TO ALL;
    CREATE TABLE ${DATASTORE_DATABASE}.\`*\` (x UInt8, y UInt8) ENGINE = MergeTree ORDER BY x AS SELECT 100, 20;
    CREATE TABLE ${DATASTORE_DATABASE}.\`other\` (x UInt8, y UInt8) ENGINE = MergeTree ORDER BY x AS SELECT 100, 20;
    SELECT 'star', * FROM ${DATASTORE_DATABASE}.\`*\`;
    SELECT 'other', * FROM ${DATASTORE_DATABASE}.other;
    DROP ROW POLICY 02703_asterisk_${DATASTORE_DATABASE}_policy ON ${DATASTORE_DATABASE}.\`*\`;
"
