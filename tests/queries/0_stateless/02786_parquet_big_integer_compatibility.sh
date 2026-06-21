#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# This is parsed as text.
$DATASTORE_LOCAL -q "select toString(424242424242424242424242424242424242424242424242424242::UInt256) as x format Parquet" | $DATASTORE_LOCAL --input-format=Parquet --structure='x UInt256' -q "select * from table"

# FIXED_LEN_BYTE_ARRAY(32) is parsed as binary.
$DATASTORE_LOCAL -q "select toFixedString(42424242424242424242424242424242::UInt256::String, 32) as x format Parquet" | $DATASTORE_LOCAL --input-format=Parquet --structure='x UInt256' -q "select * from table"

# FIXED_LEN_BYTE_ARRAY(not 32) is parsed as text by the new reader.
$DATASTORE_LOCAL -q "select toFixedString(42424242424242424242424242424242::UInt256::String, 50) as x format Parquet" | $DATASTORE_LOCAL --input-format=Parquet --structure='x UInt256' -q "select * from table"

# BYTE_ARRAY of length 32 is interpreted as text by the v3 reader.
$DATASTORE_LOCAL -q "select toString(42424242424242424242424242424242::UInt256) as x format Parquet" | $DATASTORE_LOCAL --input-format=Parquet --structure='x UInt256' -q "select * from table"

