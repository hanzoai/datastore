#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS set_idx;"

$DATASTORE_CLIENT --query="
CREATE TABLE set_idx
(
    u64 UInt64,
    i32 Int32,
    INDEX idx (i32) TYPE set(2) GRANULARITY 1
) ENGINE = MergeTree()
ORDER BY u64
SETTINGS index_granularity = 6, index_granularity_bytes = '10Mi';"

$DATASTORE_CLIENT --query="
INSERT INTO set_idx
SELECT number, number FROM system.numbers LIMIT 100"

# simple select
$DATASTORE_CLIENT --query="SELECT * FROM set_idx WHERE i32 > 0 SETTINGS optimize_move_to_prewhere = 1, query_plan_optimize_prewhere = 1 FORMAT JSON" | grep "rows_read"


$DATASTORE_CLIENT --query="DROP TABLE set_idx;"
