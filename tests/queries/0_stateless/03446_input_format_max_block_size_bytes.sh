#!/bin/bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select number from numbers(1000000) format RowBinary" > $DATASTORE_TEST_UNIQUE_NAME.bin
$DATASTORE_LOCAL -q "select count(distinct(blockNumber())) from file('$DATASTORE_TEST_UNIQUE_NAME.bin', RowBinary, 'x UInt64') settings input_format_max_block_size_bytes=1000000, max_block_size=1000000"
$DATASTORE_LOCAL -q "select count(distinct(blockNumber())) from file('$DATASTORE_TEST_UNIQUE_NAME.bin', RowBinary, 'x UInt64') settings input_format_max_block_size_bytes=100000, max_block_size=1000000"
$DATASTORE_LOCAL -q "select count(distinct(blockNumber())) from file('$DATASTORE_TEST_UNIQUE_NAME.bin', RowBinary, 'x UInt64') settings input_format_max_block_size_bytes=10000, max_block_size=1000000"

rm $DATASTORE_TEST_UNIQUE_NAME.bin

