#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 'Hello' as c1, 42 as c2 format Parquet" > $DATASTORE_TEST_UNIQUE_NAME.1.parquet
$DATASTORE_LOCAL -q "select 42 as c1, 'Hello' as c2 format Parquet" > $DATASTORE_TEST_UNIQUE_NAME.2.parquet
$DATASTORE_LOCAL -m -q "
select sleepEachRow(2);
desc file('$DATASTORE_TEST_UNIQUE_NAME.*.parquet') format Null;
select * from file('$DATASTORE_TEST_UNIQUE_NAME.1.parquet');
select * from file('$DATASTORE_TEST_UNIQUE_NAME.2.parquet');
"

rm $DATASTORE_TEST_UNIQUE_NAME.*
