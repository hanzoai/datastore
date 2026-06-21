#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS test_date_out_of_range sync";
$DATASTORE_CLIENT --query="CREATE TABLE test_date_out_of_range (f String, t Date) engine=Memory()";

printf '"above", 2200-12-31
"below", 1900-01-01
' | $DATASTORE_CLIENT --input_format_defaults_for_omitted_fields=1 --input_format_csv_empty_as_default=1 --query="INSERT INTO test_date_out_of_range FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM test_date_out_of_range";
$DATASTORE_CLIENT --query="DROP TABLE test_date_out_of_range";