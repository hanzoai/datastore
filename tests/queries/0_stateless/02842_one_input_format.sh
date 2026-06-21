#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

FILE_DIR=$DATASTORE_TEST_UNIQUE_NAME
mkdir -p $FILE_DIR

$DATASTORE_LOCAL -q "select * from numbers(100000) format Native" > $FILE_DIR/data.native
$DATASTORE_LOCAL -q "select * from numbers(100000) format CSV" > $FILE_DIR/data.csv
$DATASTORE_LOCAL -q "select * from numbers(100000) format JSONEachRow" > $FILE_DIR/data.jsonl

$DATASTORE_LOCAL -q "desc file('$FILE_DIR/*', One)"
$DATASTORE_LOCAL -q "select * from file('$FILE_DIR/*', One)"
$DATASTORE_LOCAL -q "select _file from file('$FILE_DIR/*', One) order by _file"
$DATASTORE_LOCAL -q "select * from file('$FILE_DIR/*', One, 'x UInt8')"
$DATASTORE_LOCAL -q "select * from file('$FILE_DIR/*', One, 'x UInt64')" 2>&1 | grep "BAD_ARGUMENTS" -c
$DATASTORE_LOCAL -q "select * from file('$FILE_DIR/*', One, 'x UInt8, y UInt8')" 2>&1 | grep "BAD_ARGUMENTS" -c

rm -rf $FILE_DIR

