#!/usr/bin/env bash
# Tags: long

# This test was split in two due to long runtimes in sanitizers.
# The other part is 02099_tsv_raw_format_2.sh.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_02099"
$DATASTORE_CLIENT -q "CREATE TABLE test_02099 (number UInt64, string String, date Date) ENGINE=Memory()"

FORMATS=('TSVRaw' 'TSVRawWithNames' 'TSVRawWithNamesAndTypes' 'TabSeparatedRaw'  'TabSeparatedRawWithNames'  'TabSeparatedRawWithNamesAndTypes')

for format in "${FORMATS[@]}"
do
    echo $format
    $DATASTORE_CLIENT -q "INSERT INTO test_02099 SELECT number, toString(number), toDate(number) FROM numbers(3)"
    $DATASTORE_CLIENT -q "SELECT * FROM test_02099 FORMAT $format"

    $DATASTORE_CLIENT -q "SELECT * FROM test_02099 FORMAT $format" | $DATASTORE_CLIENT -q "INSERT INTO test_02099 FORMAT $format"
    $DATASTORE_CLIENT -q "SELECT * FROM test_02099"

    $DATASTORE_CLIENT -q "TRUNCATE TABLE test_02099"
done

$DATASTORE_CLIENT -q "DROP TABLE test_02099"

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_nullable_02099"
$DATASTORE_CLIENT -q "CREATE TABLE test_nullable_02099 ENGINE=Memory() AS SELECT number % 2 ? NULL : number from numbers(4)";

$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_02099 FORMAT TSVRaw"
$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_02099 FORMAT TSVRaw" | $DATASTORE_CLIENT -q "INSERT INTO test_nullable_02099 FORMAT TSVRaw"
$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_02099"


$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_02099 FORMAT TSV" | $DATASTORE_CLIENT -q "INSERT INTO test_nullable_02099 FORMAT TSVRaw"
$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_02099 FORMAT TSVRaw" | $DATASTORE_CLIENT -q "INSERT INTO test_nullable_02099 FORMAT TSV"
$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_02099"

$DATASTORE_CLIENT -q "DROP TABLE test_nullable_02099"


$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_nullable_string_02099"
$DATASTORE_CLIENT -q "CREATE TABLE test_nullable_string_02099 (s Nullable(String)) ENGINE=Memory()";

echo 'nSome text' | $DATASTORE_CLIENT -q "INSERT INTO test_nullable_string_02099 FORMAT TSVRaw"

$DATASTORE_CLIENT -q "SELECT * FROM test_nullable_string_02099"
$DATASTORE_CLIENT -q "DROP TABLE test_nullable_string_02099"
