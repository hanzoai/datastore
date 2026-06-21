#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e -o pipefail

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS test_00598"
$DATASTORE_CURL -sS -d 'CREATE TABLE test_00598 ENGINE = Memory AS SELECT 1' "$DATASTORE_URL"
$DATASTORE_CLIENT --query="SELECT * FROM test_00598"
$DATASTORE_CLIENT --query="DROP TABLE test_00598"
