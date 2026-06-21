#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_agg"

$DATASTORE_CLIENT -q "CREATE TABLE test_agg ( A Int64, B Int64 ) Engine=MergeTree() ORDER BY (A, B)"
$DATASTORE_CLIENT -q "INSERT INTO test_agg SELECT intDiv(number, 1e5), number FROM numbers(1e6)"

$DATASTORE_CLIENT --optimize_aggregation_in_order 1 -q "SELECT A, B, count() FROM test_agg where A = 1 GROUP BY A, B ORDER BY A, B LIMIT 3"
$DATASTORE_CLIENT --optimize_aggregation_in_order 1 -q "EXPLAIN actions = 1 SELECT A, B, count() FROM test_agg where A = 1 GROUP BY A, B ORDER BY A, B LIMIT 3" | grep -o "ReadType: InOrder"

$DATASTORE_CLIENT --optimize_aggregation_in_order 1 -q "SELECT B, count() FROM test_agg where A = 1 GROUP BY B ORDER BY B LIMIT 3"
$DATASTORE_CLIENT --optimize_aggregation_in_order 1 -q "EXPLAIN actions = 1 SELECT B, count() FROM test_agg where A = 1 GROUP BY B ORDER BY B LIMIT 3" | grep -o "ReadType: InOrder"

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_agg"
