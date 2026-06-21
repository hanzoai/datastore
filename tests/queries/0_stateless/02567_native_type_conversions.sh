#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 42::UInt8 as x format Native" | $DATASTORE_LOCAL --structure="x UInt64" --input-format="Native" -q "select * from table" --input_format_native_allow_types_conversion=0 2>&1 | grep "TYPE_MISMATCH" -c

$DATASTORE_LOCAL -q "select 42::UInt8 as x format Native" | $DATASTORE_LOCAL --structure="x UInt64" --input-format="Native" -q "select * from table" --input_format_native_allow_types_conversion=1

$DATASTORE_LOCAL -q "select 'Hello' as x format Native" | $DATASTORE_LOCAL --structure="x UInt64" --input-format="Native" -q "select * from table" --input_format_native_allow_types_conversion=1 2>&1 | grep 'while converting column "x" from type String to type UInt64' -c

