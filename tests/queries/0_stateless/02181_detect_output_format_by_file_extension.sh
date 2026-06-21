#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_LOCAL -q "select * from numbers(10)" > $DATASTORE_TMP/data.parquet
$DATASTORE_LOCAL -q "select * from table" < $DATASTORE_TMP/data.parquet 

$DATASTORE_CLIENT -q "select * from numbers(10)" > $DATASTORE_TMP/data.parquet
$DATASTORE_LOCAL -q "select * from table" < $DATASTORE_TMP/data.parquet 
