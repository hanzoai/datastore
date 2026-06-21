#!/usr/bin/env bash
# Tags: memory-engine

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS empty_strings_deserialization"
$DATASTORE_CLIENT -q "CREATE TABLE empty_strings_deserialization(s String, i Int32, f Float32) ENGINE Memory"

echo ',,' | $DATASTORE_CLIENT -q "INSERT INTO empty_strings_deserialization FORMAT CSV"
echo 'aaa,,' | $DATASTORE_CLIENT -q "INSERT INTO empty_strings_deserialization FORMAT CSV"
echo 'bbb,,-0' | $DATASTORE_CLIENT -q "INSERT INTO empty_strings_deserialization FORMAT CSV"

$DATASTORE_CLIENT -q "SELECT * FROM empty_strings_deserialization ORDER BY s"

$DATASTORE_CLIENT -q "DROP TABLE empty_strings_deserialization"
