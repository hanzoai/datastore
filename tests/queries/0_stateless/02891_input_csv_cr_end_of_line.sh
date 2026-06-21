#!/usr/bin/env bash

# NOTE: this sh wrapper is required because of shell_config

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists test_tbl"
$DATASTORE_CLIENT -q "create table test_tbl (a String, b String, c String) engine=MergeTree order by a"
cat $CURDIR/data_csv/csv_with_cr_end_of_line.csv | ${DATASTORE_CLIENT} -q "INSERT INTO test_tbl SETTINGS input_format_csv_allow_cr_end_of_line=true FORMAT CSV"
$DATASTORE_CLIENT -q "select * from test_tbl"
$DATASTORE_CLIENT -q "drop table test_tbl"