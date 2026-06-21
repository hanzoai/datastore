#!/usr/bin/env bash
# Tags: zookeeper, long, no-parallel

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# with Atomic engine
$DATASTORE_CLIENT --query "CREATE USER u1"
$DATASTORE_CLIENT --query "CREATE ROLE r1"

function run_concurrent_grants
{
    for _ in {1..20}; do
        ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "GRANT r1 TO u1"
        ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "REVOKE r1 FROM u1"
    done
}
export -f run_concurrent_grants

for _ in {1..20}; do
    bash -c run_concurrent_grants &
done

wait

$DATASTORE_CLIENT --query "DROP ROLE r1"
$DATASTORE_CLIENT --query "DROP USER u1"

