#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "CREATE TABLE IF NOT EXISTS default_table (x UInt32, y UInt32 DEFAULT 42, z UInt32 DEFAULT 33) ENGINE = Memory;"

echo "(DEFAULT, 1, DEFAULT), (1, DEFAULT, 2)" | $DATASTORE_CLIENT --input_format_values_interpret_expressions=0 -q "INSERT INTO default_table FORMAT Values"
echo "(2, DEFAULT), (3, 3)" | $DATASTORE_CLIENT --input_format_values_interpret_expressions=0 -q "INSERT INTO default_table(x, z) FORMAT Values"

echo "(DEFAULT, DEFAULT, DEFAULT), (4, DEFAULT, 3)" | $DATASTORE_CLIENT --input_format_values_interpret_expressions=1 -q "INSERT INTO default_table FORMAT Values"
echo "(5, DEFAULT), (6, 6)" | $DATASTORE_CLIENT --input_format_values_interpret_expressions=1 -q "INSERT INTO default_table(x, y) FORMAT Values"

$DATASTORE_CLIENT --query="SELECT * FROM default_table ORDER BY x, y";
$DATASTORE_CLIENT --query="DROP TABLE default_table"
