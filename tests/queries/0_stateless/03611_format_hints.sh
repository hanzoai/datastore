#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL --query="SELECT 1 format CSVt" 2>&1 | grep -q "Maybe you meant: \['CSV','TSV'\]" && echo 'OK' || echo 'FAIL'

$DATASTORE_LOCAL --query="SELECT 1 format PrettyJSON" 2>&1 | grep -q "Maybe you meant: \['PrettyNDJSON'\]" && echo 'OK' || echo 'FAIL'
