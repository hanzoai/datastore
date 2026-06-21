#!/usr/bin/env bash
# Tags: no-debug, long, no-flaky-check
# long - under sanitizers this test can run for more than 180 seconds

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# In case of parallel parsing and small block
# (--min_chunk_bytes_for_parallel_parsing) we may have multiple blocks, and
# this will break sorting order, so let's limit number of threads to avoid
# reordering.
DATASTORE_CLIENT+="--allow_repeated_settings --max_threads 1"

echo "Integers"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select number::Bool as bool, number::Int8 as int8, number::UInt8 as uint8, number::Int16 as int16, number::UInt16 as uint16, number::Int32 as int32, number::UInt32 as uint32, number::Int64 as int64, number::UInt64 as uint64 from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'bool Bool, int8 Int8, uint8 UInt8, int16 Int16, uint16 UInt16, int32 Int32, uint32 UInt32, int64 Int64, uint64 UInt64')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"

echo "Integers conversion"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 UInt64, int64 Int64') select 4294967297, -4294967297 settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 UInt32, int64 UInt32')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 Int32, int64 Int32')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 UInt16, int64 UInt16')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 Int16, int64 Int16')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 UInt8, int64 UInt8')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uint64 Int8, int64 Int8')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Floats"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'float32 Float32, float64 Float64') select number / (number + 1), number / (number + 1) from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'float32 Float32, float64 Float64')";


$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Big integers"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'int128 Int128, uint128 UInt128, int256 Int256, uint256 UInt256') select number * -10000000000000000000000::Int128 as int128, number * 10000000000000000000000::UInt128 as uint128, number * -100000000000000000000000000000000000000000000::Int256 as int256, number * 100000000000000000000000000000000000000000000::UInt256 as uint256 from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'int128 Int128, uint128 UInt128, int256 Int256, uint256 UInt256')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Dates"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'date Date, date32 Date32, datetime DateTime(\'UTC\'), datetime64 DateTime64(6, \'UTC\')') select number, number, number, number from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'date Date, date32 Date32, datetime DateTime(\'UTC\'), datetime64 DateTime64(6, \'UTC\')')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Decimals"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'decimal32 Decimal32(3), decimal64 Decimal64(6), decimal128 Decimal128(12), decimal256 Decimal256(24)') select number * 42.422::Decimal32(3) as decimal32, number * 42.424242::Decimal64(6) as decimal64, number * 42.424242424242::Decimal128(12) as decimal128, number * 42.424242424242424242424242::Decimal256(24) as decimal256 from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'decimal32 Decimal32(3), decimal64 Decimal64(6), decimal128 Decimal128(12), decimal256 Decimal256(24)')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Strings"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'str String, fixstr FixedString(5)') select repeat('HelloWorld', number), repeat(char(97 + number), number % 6) from numbers(5) settings engine_file_truncate_on_insert=1, output_format_bson_string_as_string=0"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'str String, fixstr FixedString(5)')"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'str String, fixstr FixedString(5)') select repeat('HelloWorld', number), repeat(char(97 + number), number % 6) from numbers(5) settings engine_file_truncate_on_insert=1, output_format_bson_string_as_string=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'str String, fixstr FixedString(5)')"


$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "UUID"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uuid UUID') select 'b86d5c23-4b87-4465-8f33-4a685fa1c868'::UUID settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'uuid UUID')"


$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "LowCardinality"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'lc LowCardinality(String)') select char(97 + number % 3)::LowCardinality(String) from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'lc LowCardinality(String)')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Nullable"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'null Nullable(UInt32)') select number % 2 ? NULL : number from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'null Nullable(UInt32)')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'null UInt32')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'null UInt32') settings input_format_null_as_default=0" 2>&1 | grep -q -F "ILLEGAL_COLUMN" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "LowCardinality(Nullable)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'lc LowCardinality(Nullable(String))') select number % 2 ? NULL : char(97 + number % 3)::LowCardinality(String) from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'lc LowCardinality(Nullable(String))')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Array"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'arr1 Array(UInt64), arr2 Array(String)') select range(number), ['Hello'] from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'arr1 Array(UInt64), arr2 Array(String)') settings engine_file_truncate_on_insert=1" 

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Tuple"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(x UInt64, s String)') select tuple(number, 'Hello') from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(x UInt64, s String)')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(s String, x UInt64)')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(x UInt64)')" 2>&1 | grep -q -F "INCORRECT_DATA" && echo "OK" || echo "FAIL"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(x UInt64, b String)')" 2>&1 | grep -q -F "INCORRECT_DATA" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(UInt64, String)') select tuple(number, 'Hello') from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(x UInt64, s String)')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(UInt64, String)')"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(UInt64)')" 2>&1 | grep -q -F "INCORRECT_DATA" && echo "OK" || echo "FAIL"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'tuple Tuple(UInt64, String, UInt64)')" 2>&1 | grep -q -F "INCORRECT_DATA" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Map"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'map Map(UInt64, UInt64)') select map(1, number, 2, number + 1) from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'map Map(UInt64, UInt64)')"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'map Map(String, UInt64)') select map('a', number, 'b', number + 1) from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'map Map(String, UInt64)')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Nested types"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'nested1 Array(Array(UInt32)), nested2 Tuple(Tuple(x UInt32, s String), String), nested3 Map(String, Map(String, UInt32))') select [range(number), range(number + 1)], tuple(tuple(number, 'Hello'), 'Hello'), map('a', map('a.a', number, 'a.b', number + 1), 'b', map('b.a', number, 'b.b', number + 1)) from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'nested1 Array(Array(UInt32)), nested2 Tuple(Tuple(x UInt32, s String), String), nested3 Map(String, Map(String, UInt32))')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'nested Array(Tuple(Map(String, Array(UInt32)), Array(Map(String, Tuple(Array(UInt64), Array(UInt64))))))') select [(map('a', range(number), 'b', range(number + 1)), [map('c', (range(number), range(number + 1))), map('d', (range(number + 2), range(number + 3)))])] from numbers(5) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'nested Array(Tuple(Map(String, Array(UInt32)), Array(Map(String, Tuple(Array(UInt64), Array(UInt64))))))')"

$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "select * from file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"


echo "Schema inference"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select number::Bool as x from numbers(2) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select number::Int32 as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select number::UInt32 as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select number::Int64 as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select toString(number) as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)" 2>&1 | grep -q -F "TYPE_MISMATCH" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [number::Bool] as x from numbers(2) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [number::Int32] as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [number::UInt32] as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [number::Int64] as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [toString(number)] as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)" 2>&1 | grep -q -F "TYPE_MISMATCH" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [] as x from numbers(2) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)" 2>&1 | grep -q -F "ONLY_NULLS_WHILE_READING_SCHEMA" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select NULL as x from numbers(2) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)" 2>&1 | grep -q -F "ONLY_NULLS_WHILE_READING_SCHEMA" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select [NULL, 1] as x from numbers(2) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)" 2>&1 | grep -q -F "ONLY_NULLS_WHILE_READING_SCHEMA" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select tuple(1, 'str') as x from numbers(2) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q "insert into function file(02475_data_${DATASTORE_DATABASE}.bsonEachRow) select tuple(1) as x from numbers(2)"
$DATASTORE_CLIENT -q "desc file(02475_data_${DATASTORE_DATABASE}.bsonEachRow)" 2>&1 | grep -q -F "TYPE_MISMATCH" && echo "OK" || echo "FAIL"


echo "Sync after error"
$DATASTORE_CLIENT -q "insert into function file(data_${DATASTORE_DATABASE}.bsonEachRow) select number, 42::Int128 as int, range(number) as arr from numbers(3) settings engine_file_truncate_on_insert=1"
$DATASTORE_CLIENT -q " insert into function file(data_${DATASTORE_DATABASE}.bsonEachRow) select number, 'Hello' as int, range(number) as arr from numbers(2) settings engine_file_truncate_on_insert=0"
$DATASTORE_CLIENT -q "insert into function file(data_${DATASTORE_DATABASE}.bsonEachRow) select number, 42::Int128 as int, range(number) as arr from numbers(3) settings engine_file_truncate_on_insert=0"
$DATASTORE_CLIENT -q "select * from file(data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'number UInt64, int Int128, arr Array(UInt64)') settings input_format_allow_errors_num=0"  2>&1 | grep -q -F "INCORRECT_DATA" && echo "OK" || echo "FAIL"
$DATASTORE_CLIENT -q "select * from file(data_${DATASTORE_DATABASE}.bsonEachRow, auto, 'number UInt64, int Int128, arr Array(UInt64)') settings input_format_allow_errors_num=2"
