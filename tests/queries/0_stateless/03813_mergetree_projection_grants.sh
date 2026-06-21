#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel

# Test that mergeTreeProjection checks table grants correctly.
# This function should require SELECT permission on the source table.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_proj_grants_mt"
$DATASTORE_CLIENT -q "DROP USER IF EXISTS test_user_03813"

$DATASTORE_CLIENT -q "
CREATE TABLE test_proj_grants_mt (key Int, value Int, PROJECTION proj_sum (SELECT key, sum(value) GROUP BY key))
ENGINE = MergeTree() ORDER BY key
"

$DATASTORE_CLIENT -q "INSERT INTO test_proj_grants_mt SELECT number % 10, number FROM numbers(1000)"
$DATASTORE_CLIENT -q "OPTIMIZE TABLE test_proj_grants_mt FINAL"

# Create user without any grants
$DATASTORE_CLIENT -q "CREATE USER test_user_03813"

# Test mergeTreeProjection - should fail without SELECT grant
echo "=== mergeTreeProjection without grant ==="
$DATASTORE_CLIENT --user test_user_03813 -q "
SELECT count() FROM mergeTreeProjection(currentDatabase(), test_proj_grants_mt, proj_sum)
" 2>&1 | grep -o 'ACCESS_DENIED' | head -1

# Grant SELECT permission
$DATASTORE_CLIENT -q "GRANT SELECT ON ${DATASTORE_DATABASE}.test_proj_grants_mt TO test_user_03813"

# Test mergeTreeProjection - should work with SELECT grant
echo "=== mergeTreeProjection with grant ==="
$DATASTORE_CLIENT --user test_user_03813 -q "
SELECT count() > 0 FROM mergeTreeProjection(currentDatabase(), test_proj_grants_mt, proj_sum)
"

# Cleanup
$DATASTORE_CLIENT -q "DROP TABLE test_proj_grants_mt"
$DATASTORE_CLIENT -q "DROP USER test_user_03813"
