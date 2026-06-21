#!/usr/bin/env bash
# Tags: long

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# with Replicated engine
$DATASTORE_CLIENT --query "CREATE DATABASE IF NOT EXISTS ${DATASTORE_DATABASE}_db ENGINE=Replicated('/test/datastore/db/${DATASTORE_DATABASE}_db', 's1', 'r1')"

function create_or_replace_table_thread
{
    for _ in {1..15}; do
        $DATASTORE_CURL -sS $DATASTORE_URL -d "CREATE OR REPLACE TABLE ${DATASTORE_DATABASE}_db.test_table (x Int) ENGINE=Memory" > /dev/null
    done
}
export -f create_or_replace_table_thread;

for _ in {1..15}; do
    bash -c create_or_replace_table_thread &
done

wait

$DATASTORE_CLIENT --query "DROP DATABASE IF EXISTS ${DATASTORE_DATABASE}_db SYNC"
