#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 'Hello\rWorld' from numbers(1000000) format TSVRaw" > $DATASTORE_TEST_UNIQUE_NAME.csv
$DATASTORE_LOCAL -q "desc file('$DATASTORE_TEST_UNIQUE_NAME.csv')"
$DATASTORE_LOCAL -q "select count() from file('$DATASTORE_TEST_UNIQUE_NAME.csv') settings optimize_count_from_files=0"
$DATASTORE_LOCAL -q "select count() from file('$DATASTORE_TEST_UNIQUE_NAME.csv') settings optimize_count_from_files=1"
$DATASTORE_LOCAL -q "select * from file('$DATASTORE_TEST_UNIQUE_NAME.csv') limit 1"

rm $DATASTORE_TEST_UNIQUE_NAME.csv

