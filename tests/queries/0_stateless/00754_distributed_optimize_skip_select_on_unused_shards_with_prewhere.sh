#!/usr/bin/env bash
# Tags: distributed

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS distributed_00754;"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS mergetree_00754;"

${DATASTORE_CLIENT} --query "
    CREATE TABLE mergetree_00754 (a Int64, b Int64, c String) ENGINE = MergeTree ORDER BY (a, b);
"
${DATASTORE_CLIENT} --query "
    CREATE TABLE distributed_00754 AS mergetree_00754
    ENGINE = Distributed(test_unavailable_shard, ${DATASTORE_DATABASE}, mergetree_00754, jumpConsistentHash(a+b, 2));
"

${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (0, 0, 'Hello');"
${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (1, 0, 'World');"
${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (0, 1, 'Hello');"
${DATASTORE_CLIENT} --query "INSERT INTO mergetree_00754 VALUES (1, 1, 'World');"

# Should fail because the second shard is unavailable
${DATASTORE_CLIENT} --optimize_skip_unused_shards 0 --query "SELECT count(*) FROM distributed_00754;" 2>&1 \
| grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

# Should fail without setting `optimize_skip_unused_shards` = 1
${DATASTORE_CLIENT} --optimize_skip_unused_shards 0 --query "SELECT count(*) FROM distributed_00754 PREWHERE a = 0 AND b = 0;" 2>&1 \
| grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

# Should pass now
${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 AND b = 0;
"


# Should still fail because of matching unavailable shard
${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 2 AND b = 2;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

# Try more complex expressions for constant folding - all should pass.

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 1 AND a = 0 WHERE b = 0;
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 1 WHERE b = 1 AND length(c) = 5;
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a IN (0, 1) AND b IN (0, 1) WHERE c LIKE '%l%';
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a IN (0, 1) WHERE b IN (0, 1) AND c LIKE '%l%';
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 AND b = 0 OR a = 1 AND b = 1 WHERE c LIKE '%l%';
"

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE (a = 0 OR a = 1) WHERE (b = 0 OR b = 1);
"

# These should fail.

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 AND b <= 1;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 WHERE c LIKE '%l%';
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 OR a = 1 AND b = 0;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 AND b = 0 OR a = 2 AND b = 2;
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query="
    SET optimize_skip_unused_shards = 1;
    SELECT count(*) FROM distributed_00754 PREWHERE a = 0 AND b = 0 OR c LIKE '%l%';
" 2>&1 \ | grep -F -q "All connection tries failed" && echo 'OK' || echo 'FAIL'

$DATASTORE_CLIENT -q "DROP TABLE distributed_00754"
$DATASTORE_CLIENT -q "DROP TABLE mergetree_00754"
