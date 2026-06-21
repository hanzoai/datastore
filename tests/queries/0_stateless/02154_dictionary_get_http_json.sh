#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS 02154_test_source_table"

$DATASTORE_CLIENT -q """
    CREATE TABLE 02154_test_source_table
    (
        id UInt64,
        value String
    ) ENGINE=TinyLog;
"""

$DATASTORE_CLIENT -q "INSERT INTO 02154_test_source_table VALUES (0, 'Value')"
$DATASTORE_CLIENT -q "SELECT * FROM 02154_test_source_table"

$DATASTORE_CLIENT -q "DROP DICTIONARY IF EXISTS 02154_test_dictionary"
$DATASTORE_CLIENT -q """
    CREATE DICTIONARY 02154_test_dictionary
    (
        id UInt64,
        value String
    )
    PRIMARY KEY id
    LAYOUT(HASHED())
    LIFETIME(0)
    SOURCE(DATASTORE(TABLE '02154_test_source_table'))
"""

echo """
    SELECT dictGet(02154_test_dictionary, 'value', toUInt64(0)), dictGet(02154_test_dictionary, 'value', toUInt64(1))
    SETTINGS enable_analyzer = 1
    FORMAT JSON
""" | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}&http_wait_end_of_query=1&output_format_write_statistics=0" -d @-

$DATASTORE_CLIENT -q "DROP DICTIONARY 02154_test_dictionary"
$DATASTORE_CLIENT -q "DROP TABLE 02154_test_source_table"
