#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 42 as x format Parquet" | $DATASTORE_LOCAL --input-format Parquet --structure "x UInt32, y UInt32" --input_format_parquet_allow_missing_columns=0 -q "select * from table" 2>&1 | grep -c "THERE_IS_NO_COLUMN"

