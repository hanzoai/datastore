#!/usr/bin/env bash
# Tags: no-fasttest

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

QUERY_FIELD_NUM=4

$DATASTORE_CLIENT --max_block_size=1 -q "SELECT sleep(1) FROM system.numbers LIMIT 300" &>/dev/null &

while true
do
    $DATASTORE_CLIENT --query "KILL QUERY WHERE current_database = '${DATASTORE_DATABASE}' AND query LIKE 'SELECT sleep(%' AND (elapsed >= 0.) SYNC" | cut -f $QUERY_FIELD_NUM | grep '.' && break
    sleep 0.1
done

# 31 is for the query to be different from the previous one
$DATASTORE_CLIENT --max_block_size=1 -q "SELECT sleep(1) FROM system.numbers LIMIT 301" &>/dev/null &

while true
do
    $DATASTORE_CLIENT --query "KILL QUERY WHERE current_database = '${DATASTORE_DATABASE}' AND query = 'SELECT sleep(1) FROM system.numbers LIMIT 301' ASYNC" | cut -f $QUERY_FIELD_NUM | grep '.' && break
    sleep 0.1
done

$DATASTORE_CLIENT -q "KILL QUERY WHERE 0 ASYNC"
$DATASTORE_CLIENT -q "KILL QUERY WHERE 0 FORMAT TabSeparated"
$DATASTORE_CLIENT -q "KILL QUERY WHERE 0 SYNC FORMAT TabSeparated"
$DATASTORE_CLIENT -q "KILL QUERY WHERE 1 TEST" &>/dev/null
