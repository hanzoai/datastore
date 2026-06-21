#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS csv";

$DATASTORE_CLIENT --query="CREATE TABLE csv (s String, n UInt64, d Date) ENGINE = Memory";

echo "'single quote' not end, 123, 2016-01-01
'em good, 456, 2016-01-02" | $DATASTORE_CLIENT --format_csv_allow_single_quotes=0 --query="INSERT INTO csv FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM csv ORDER BY d";

$DATASTORE_CLIENT --query="DROP TABLE csv";

$DATASTORE_CLIENT --query="CREATE TABLE csv (s String, n UInt64, d Date) ENGINE = Memory";

echo "'single quote' not end, 123, 2016-01-01
'em good, 456, 2016-01-02" | $DATASTORE_CLIENT --query="SET format_csv_allow_single_quotes=0; INSERT INTO csv FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM csv ORDER BY d";

$DATASTORE_CLIENT --query="DROP TABLE csv";

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS csv";

$DATASTORE_CLIENT --query="CREATE TABLE csv (s String, n UInt64, d Date) ENGINE = Memory";

echo '"double quote" not end, 123, 2016-01-01
"em good, 456, 2016-01-02' | $DATASTORE_CLIENT --format_csv_allow_double_quotes=0 --query="INSERT INTO csv FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM csv ORDER BY d";

$DATASTORE_CLIENT --query="DROP TABLE csv";

$DATASTORE_CLIENT --query="CREATE TABLE csv (s String, n UInt64, d Date) ENGINE = Memory";

echo '"double quote" not end, 123, 2016-01-01
"em good, 456, 2016-01-02' | $DATASTORE_CLIENT --query="SET format_csv_allow_double_quotes=0; INSERT INTO csv FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM csv ORDER BY d";

$DATASTORE_CLIENT --query="DROP TABLE csv";
