#!/usr/bin/env bash
# shellcheck disable=SC2009

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

user=user_$DATASTORE_TEST_UNIQUE_NAME
$DATASTORE_CLIENT --query "DROP USER IF EXISTS $user"
$DATASTORE_CLIENT --query "CREATE USER $user IDENTIFIED WITH PLAINTEXT_PASSWORD BY 'hello'"
$DATASTORE_CLIENT --query "GRANT SELECT ON system.numbers TO $user"
trap '$DATASTORE_CLIENT --query "DROP USER $user"' EXIT

# Wait for query to start executing. At that time, the password should be cleared.
function wait_query_pid()
{
    local query_id=$1 && shift

    for _ in {1..20}; do
        if [ "$($DATASTORE_CLIENT --param_query_id "$query_id" --query "SELECT count() FROM system.processes WHERE query_id = {query_id:String}")" -eq 1 ]; then
            break
        fi
        sleep 0.3
    done
}

# --password <pass>
query_id=first-$DATASTORE_TEST_UNIQUE_NAME
$DATASTORE_CLIENT --query_id "$query_id" --user "$user" --password hello --max_block_size 1 --query "SELECT sleepEachRow(1) FROM system.numbers LIMIT 100" >& /dev/null &
bg_query=$!
wait_query_pid "$query_id"
ps u --no-header $bg_query | grep -F -- '--password' | grep -F hello ||:
grep -F -- '--password' < "/proc/$bg_query/comm" | grep -F hello ||:
$DATASTORE_CLIENT --format Null --param_query_id "$query_id" -q "KILL QUERY WHERE query_id = {query_id:String} SYNC"
wait

# --password=<pass>
query_id=second-$DATASTORE_TEST_UNIQUE_NAME
$DATASTORE_CLIENT --query_id "$query_id" --user "$user" --password=hello --max_block_size 1 --query "SELECT sleepEachRow(1) FROM system.numbers LIMIT 100" >& /dev/null &
bg_query=$!
wait_query_pid "$query_id"
ps u --no-header $bg_query | grep -F -- '--password' | grep -F hello ||:
grep -F -- '--password' < "/proc/$bg_query/comm" | grep -F hello ||:
$DATASTORE_CLIENT --format Null --param_query_id "$query_id" -q "KILL QUERY WHERE query_id = {query_id:String} SYNC"
wait

$DATASTORE_CLIENT --user "$user" --password=hello --password -q 'select currentUser()' 2>&1 | grep -o 'Bad arguments'
