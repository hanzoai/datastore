#!/usr/bin/env bash
# Tags: no-fasttest, no-msan, no-ubsan

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

mkdir -p $DATASTORE_TEST_UNIQUE_NAME
echo '{"a" : 1, "obj" : {"f1" : 1, "f2" : "2020-01-01"}}' > $DATASTORE_TEST_UNIQUE_NAME/data1.jsonl
echo '{"b" : 2, "obj" : {"f3" : 2, "f2" : "Some string"}}' > $DATASTORE_TEST_UNIQUE_NAME/data2.jsonl
echo '{"c" : "hello"}' > $DATASTORE_TEST_UNIQUE_NAME/data3.jsonl

$DATASTORE_LOCAL -m -q "
set schema_inference_mode = 'union';
desc file('$DATASTORE_TEST_UNIQUE_NAME/data{1,2,3}.jsonl');
select * from file('$DATASTORE_TEST_UNIQUE_NAME/data{1,2,3}.jsonl') order by tuple(*) format JSONEachRow;
select schema_inference_mode, splitByChar('/', source)[-1] as file, schema from system.schema_inference_cache order by file;
"

$DATASTORE_LOCAL -m -q "
set schema_inference_mode = 'union';
desc file('$DATASTORE_TEST_UNIQUE_NAME/data3.jsonl');
desc file('$DATASTORE_TEST_UNIQUE_NAME/data{1,2,3}.jsonl');
"

cd $DATASTORE_TEST_UNIQUE_NAME/ && tar -cf archive.tar data1.jsonl data2.jsonl data3.jsonl && cd ..

$DATASTORE_LOCAL -m -q "
set schema_inference_mode = 'union';
desc file('$DATASTORE_TEST_UNIQUE_NAME/archive.tar :: data{1,2,3}.jsonl');
select * from file('$DATASTORE_TEST_UNIQUE_NAME/archive.tar :: data{1,2,3}.jsonl') order by tuple(*) format JSONEachRow;
select schema_inference_mode, splitByChar('/', source)[-1] as file, schema from system.schema_inference_cache order by file;
"

$DATASTORE_LOCAL -m -q "
set schema_inference_mode = 'union';
desc file('$DATASTORE_TEST_UNIQUE_NAME/archive.tar :: data3.jsonl');
desc file('$DATASTORE_TEST_UNIQUE_NAME/archive.tar :: data{1,2,3}.jsonl');
"

echo 'Error' > $DATASTORE_TEST_UNIQUE_NAME/data4.jsonl
$DATASTORE_LOCAL -q "desc file('$DATASTORE_TEST_UNIQUE_NAME/data{1,2,3,4}.jsonl') settings schema_inference_mode='union'" 2>&1 | grep -c -F "CANNOT_EXTRACT_TABLE_STRUCTURE"

$DATASTORE_LOCAL -m -q "
set schema_inference_mode = 'union';
desc file('$DATASTORE_TEST_UNIQUE_NAME/data{2,3}.jsonl');
desc file('$DATASTORE_TEST_UNIQUE_NAME/data{1,2,3,4}.jsonl');
" 2>&1 | grep -c -F "CANNOT_EXTRACT_TABLE_STRUCTURE"

echo 42 > $DATASTORE_TEST_UNIQUE_NAME/data1.csv
echo 42, 43 > $DATASTORE_TEST_UNIQUE_NAME/data2.csv

$DATASTORE_LOCAL -q "desc file('$DATASTORE_TEST_UNIQUE_NAME/data{1,2}.csv') settings schema_inference_mode='union'" 2>&1 | grep -c -F "BAD_ARGUMENTS";

rm -rf ${DATASTORE_TEST_UNIQUE_NAME}

