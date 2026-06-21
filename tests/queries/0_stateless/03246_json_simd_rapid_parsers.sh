#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL --enable_json_type=1 --stacktrace -q "select '{\"a\" : 4ab2}'::JSON" 2>&1 | grep -c -F "SimdJSON"
$DATASTORE_LOCAL --enable_json_type=1 --allow_simdjson=0 --stacktrace -q "select '{\"a\" : 4ab2}'::JSON" 2>&1 | grep -c -F "RapidJSON"
