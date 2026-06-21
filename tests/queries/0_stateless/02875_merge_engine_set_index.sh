#!/usr/bin/env bash

# shellcheck disable=SC2154

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "
    CREATE TABLE t1
    (
        a UInt32,
        b UInt32
    )
    ENGINE = MergeTree
    ORDER BY (a, b)
    SETTINGS index_granularity = 8192;

    INSERT INTO t1 SELECT number, number FROM numbers_mt(1e6);

    CREATE TABLE t2
    (
        a UInt32,
        b UInt32
    )
    ENGINE = MergeTree
    ORDER BY (a, b)
    SETTINGS index_granularity = 8192;

    INSERT INTO t2 VALUES (1, 1) (2, 2) (3, 3);

    CREATE TABLE t
    (
        a UInt32,
        b UInt32
    )
    ENGINE = Merge(currentDatabase(), 't*');"

query_id="${DATASTORE_DATABASE}_merge_engine_set_index_$RANDOM$RANDOM"
$DATASTORE_CLIENT --query_id="$query_id" -q "
SELECT
    a,
    b
FROM t
WHERE (a, b) IN (
    SELECT DISTINCT
        a,
        b
    FROM t2
)
GROUP BY
    a,
    b
ORDER BY
    a ASC,
    b DESC
FORMAT Null;"

$DATASTORE_CLIENT -q "
SYSTEM FLUSH LOGS query_log;

SELECT ProfileEvents['SelectedMarks']
FROM system.query_log
WHERE event_date >= yesterday() AND event_time >= now() - 600 AND current_database = currentDatabase() AND (query_id = '$query_id') AND (type = 'QueryFinish');"
