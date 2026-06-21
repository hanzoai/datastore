#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

DATA_FILE=$DATASTORE_TEST_UNIQUE_NAME.arrow

$DATASTORE_LOCAL -q "
    CREATE TABLE export_table (id UUID) ENGINE = Memory;
    INSERT INTO export_table VALUES ('ce7adebf-4abe-4d4d-836e-ec8b0ab78738');
    SELECT * FROM export_table INTO OUTFILE '$DATA_FILE' FORMAT Arrow;
"

# Read without schema
$DATASTORE_LOCAL -q "SELECT toTypeName(id), id FROM file('$DATA_FILE', 'Arrow');"

rm -f $DATA_FILE