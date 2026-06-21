#!/usr/bin/env bash
# Tags: no-fasttest
#       ^ no Parquet support in fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select tuple(10, 20) as x format Parquet" |  $DATASTORE_LOCAL --input-format=Parquet --table test -q "select * from test"
$DATASTORE_LOCAL -q "select (10, 10)::Point format Parquet" |  $DATASTORE_LOCAL --input-format=Parquet --table test -q "select * from test"
$DATASTORE_LOCAL -q "select CAST(([1, 2, 3], ['Ready', 'Steady', 'Go']), 'Map(UInt8, String)') AS map format Parquet" |  $DATASTORE_LOCAL --input-format=Parquet --table test -q "select * from test"
