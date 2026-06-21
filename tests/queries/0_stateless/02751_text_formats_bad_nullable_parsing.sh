#!/usr/bin/env bash

# NOTE: this sh wrapper is required because of shell_config

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists test" 
$DATASTORE_CLIENT -q "create table test (x UInt32, y Nullable(UInt32)) engine=MergeTree order by x"
$DATASTORE_CLIENT -q "select '1\t\\\N\n2\t\\\' format RawBLOB" | $DATASTORE_CLIENT -q "insert into test settings input_format_allow_errors_num=1 format TSV"
$DATASTORE_CLIENT -q "select '1,\\\N\n2,\\\' format RawBLOB" | $DATASTORE_CLIENT -q "insert into test settings input_format_allow_errors_num=1 format CSV"
$DATASTORE_CLIENT -q "select '1\tNULL\n2\tN' format RawBLOB" | $DATASTORE_CLIENT -q "insert into test settings input_format_allow_errors_num=2, format_custom_escaping_rule='Quoted' format CustomSeparated"
$DATASTORE_CLIENT -q "select * from test"
$DATASTORE_CLIENT -q "drop table test"; 
