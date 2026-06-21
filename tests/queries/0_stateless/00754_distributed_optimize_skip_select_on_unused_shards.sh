#!/usr/bin/env bash
# Tags: distributed

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS mergetree_00754;"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS distributed;"

${DATASTORE_CLIENT} --query "CREATE TABLE mergetree_00754 (a Int64, b Int64, c Int64) ENGINE = MergeTree ORDER BY (a, b);"
${DATASTORE_CLIENT} --query "CREATE TABLE distributed AS mergetree_00754 ENGINE = Distributed(test_unavailable_shard, ${DATASTORE_DATABASE}, mergetree_00754, jumpConsistentHash(a+b, 2));"

${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (0, 0, 0);"
${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (1, 0, 0);"
${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (0, 1, 1);"
${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (1, 1, 1);"

# Should fail because second shard is unavailable
${DATASTORE_CLIENT} --optimize_skip_unused_shards 0 --query "SELECT count(*) FROM distributed;" 2>&1 \
| grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

# Should fail without setting `optimize_skip_unused_shards`
${DATASTORE_CLIENT} --optimize_skip_unused_shards 0 --query "SELECT count(*) FROM distributed WHERE a = 0 AND b = 0;" 2>&1 \
| grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

# Should pass now
${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0;
"

# Should still fail because of matching unavailable shard
${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 2 AND b = 2;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

# Try more complext expressions for constant folding - all should pass.

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 1 AND a = 0 AND b = 0;
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a IN (0, 1) AND b IN (0, 1);
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0 OR a = 1 AND b = 1;
"

# TODO: should pass one day.
#${DATASTORE_CLIENT} --query="
#    SET optimize_skip_unused_shards = 1;
#    SELECT count(*) FROM distributed WHERE a = 0 AND b >= 0 AND b <= 1;
#"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0 AND c = 0;
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0 AND c != 10;
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0 AND (a+b)*b != 12;
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE (a = 0 OR a = 1) AND (b = 0 OR b = 1);
"

# These ones should fail.

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b <= 1;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND c = 0;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 OR a = 1 AND b = 0;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0 OR a = 2 AND b = 2;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed WHERE a = 0 AND b = 0 OR c = 0;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

$DATASTORE_CLIENT -q "DROP TABLE distributed"
$DATASTORE_CLIENT -q "DROP TABLE mergetree_00754"
