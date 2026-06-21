#!/usr/bin/env bash
# Tags: race, zookeeper, no-parallel, no-shared-merge-tree
# no-shared-merge-tree: database ordinary not supported for shared merge tree

# Creation of a database with Ordinary engine emits a warning.
DATASTORE_CLIENT_SERVER_LOGS_LEVEL=fatal

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

$DATASTORE_CLIENT --query "DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1}"
$DATASTORE_CLIENT --allow_deprecated_database_ordinary=1 --query "CREATE DATABASE ${DATASTORE_DATABASE_1} ENGINE=Ordinary"   # Different bahaviour of DROP with Atomic

function thread1()
{
    local TIMELIMIT=$((SECONDS+$1))
    while [ $SECONDS -lt "$TIMELIMIT" ]; do
        $DATASTORE_CLIENT --query "CREATE TABLE ${DATASTORE_DATABASE_1}.r (x UInt64) ENGINE = ReplicatedMergeTree('/test/$DATASTORE_TEST_ZOOKEEPER_PREFIX/table', 'r') ORDER BY x; DROP TABLE ${DATASTORE_DATABASE_1}.r;"
    done
}

function thread2()
{
    local TIMELIMIT=$((SECONDS+$1))
    while [ $SECONDS -lt "$TIMELIMIT" ]; do
        $DATASTORE_CLIENT --query "SYSTEM SYNC REPLICA ${DATASTORE_DATABASE_1}.r" 2>/dev/null;
    done
}

export -f thread1
export -f thread2

TIMEOUT=10

thread1 $TIMEOUT &
thread2 $TIMEOUT &

wait

$DATASTORE_CLIENT --query "DROP DATABASE ${DATASTORE_DATABASE_1}" 2>&1 | grep -F "Code:" | grep -v "New table appeared in database being dropped or detached" || exit 0
