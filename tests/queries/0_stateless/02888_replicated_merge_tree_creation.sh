#!/usr/bin/env bash
# Tags: zookeeper, no-parallel, no-ordinary-database

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

DATASTORE_CLIENT="${DATASTORE_CLIENT} --database_replicated_allow_explicit_uuid 3 --database_replicated_allow_replicated_engine_arguments 3"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS test_exception_replicated SYNC"

UUID=$(${DATASTORE_CLIENT} --query "SELECT reinterpretAsUUID(currentDatabase())")

#### 1 - There is only one replica

${DATASTORE_CLIENT} --create_replicated_merge_tree_fault_injection_probability=1 \
    -q "CREATE TABLE test_exception_replicated UUID '$UUID' (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/recreate', 'r1') ORDER BY date" 2>&1 | grep -cm1 "Fault injected"

# We will see that the replica is empty and throw the same 'Fault injected' exception as before
${DATASTORE_CLIENT} --create_replicated_merge_tree_fault_injection_probability=1 \
    -q "CREATE TABLE test_exception_replicated UUID '$UUID' (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/recreate', 'r1') ORDER BY date" 2>&1 | grep -cm1 "Fault injected"

# We will succeed
${DATASTORE_CLIENT} \
    -q "CREATE TABLE test_exception_replicated UUID '$UUID' (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/recreate', 'r1') ORDER BY date"

${DATASTORE_CLIENT} -q "DROP TABLE test_exception_replicated SYNC"

#### 2 - There are two replicas

${DATASTORE_CLIENT} --create_replicated_merge_tree_fault_injection_probability=1 \
    -q "CREATE TABLE test_exception_replicated UUID '$UUID' (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/recreate', 'r1') ORDER BY date" 2>&1 | grep -cm1 "Fault injected"
${DATASTORE_CLIENT} --create_replicated_merge_tree_fault_injection_probability=1 \
    -q "CREATE TABLE test_exception_replicated_2 (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/recreate', 'r2') ORDER BY date" 2>&1 | grep -cm1 "Fault injected"

# We will succeed
${DATASTORE_CLIENT} \
    -q "CREATE TABLE test_exception_replicated UUID '$UUID' (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/recreate', 'r1') ORDER BY date"

# The trash from the second replica creation will not prevent us from dropping the table fully, so we delete it separately
${DATASTORE_CLIENT} -q "SYSTEM DROP REPLICA 'r2' FROM TABLE test_exception_replicated"

${DATASTORE_CLIENT} -q "DROP TABLE test_exception_replicated SYNC"