#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CURL "${DATASTORE_URL}" -X GET -d "SELECT 1" -vs 2>&1 | grep "OK"
$DATASTORE_CURL "${DATASTORE_URL}" -X aaa -vs 2>&1 | grep "Not Implemented"
$DATASTORE_CURL "${DATASTORE_URL}" -d "SELECT 1" -vs 2>&1 | grep "OK"
