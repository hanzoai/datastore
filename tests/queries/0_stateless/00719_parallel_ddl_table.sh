#!/usr/bin/env bash
# Tags: no-fasttest
set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS parallel_ddl"

function query()
{
    local it=0
    TIMELIMIT=30
    while [ $SECONDS -lt "$TIMELIMIT" ] && [ $it -lt 50 ];
    do
        it=$((it+1))
        ${DATASTORE_CLIENT} --query "CREATE TABLE IF NOT EXISTS parallel_ddl(a Int) ENGINE = Memory"
        ${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS parallel_ddl"
    done
}

for _ in {1..2}; do
    query &
done

wait

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS parallel_ddl"
