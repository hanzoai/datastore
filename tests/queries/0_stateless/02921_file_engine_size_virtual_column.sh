#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "1" > $DATASTORE_TEST_UNIQUE_NAME.data1.tsv
echo "12" > $DATASTORE_TEST_UNIQUE_NAME.data2.tsv
echo "123" > $DATASTORE_TEST_UNIQUE_NAME.data3.tsv

$DATASTORE_LOCAL -q "select _size from file('$DATASTORE_TEST_UNIQUE_NAME.data{1,2,3}.tsv') order by _size"
# Run this query twice to check correct behaviour when cache is used
$DATASTORE_LOCAL -q "select _size from file('$DATASTORE_TEST_UNIQUE_NAME.data{1,2,3}.tsv') order by _size"

# Test the same fils in archive
tar -cf $DATASTORE_TEST_UNIQUE_NAME.archive.tar $DATASTORE_TEST_UNIQUE_NAME.data1.tsv $DATASTORE_TEST_UNIQUE_NAME.data2.tsv $DATASTORE_TEST_UNIQUE_NAME.data3.tsv

$DATASTORE_LOCAL -q "select _size from file('$DATASTORE_TEST_UNIQUE_NAME.archive.tar :: $DATASTORE_TEST_UNIQUE_NAME.data{1,2,3}.tsv') order by _size"
$DATASTORE_LOCAL -q "select _size from file('$DATASTORE_TEST_UNIQUE_NAME.archive.tar :: $DATASTORE_TEST_UNIQUE_NAME.data{1,2,3}.tsv') order by _size"

rm $DATASTORE_TEST_UNIQUE_NAME.*

