#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel, long

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

NUM_DATABASES=300
user="user_03821_$DATASTORE_DATABASE"

# Build PARALLEL WITH compound queries for create/drop
query_create=""
query_drop=""
for i in $(seq 1 $NUM_DATABASES); do
    if [ -n "$query_create" ]; then
        query_create+=" PARALLEL WITH "
        query_drop+=" PARALLEL WITH "
    fi
    query_create+="CREATE DATABASE IF NOT EXISTS test_03821_db_$i ENGINE=Memory"
    query_drop+="DROP DATABASE IF EXISTS test_03821_db_$i"
done

function cleanup()
{
    $DATASTORE_CLIENT --query "$query_drop" 2>/dev/null
    $DATASTORE_CLIENT --query "DROP USER IF EXISTS $user" 2>/dev/null
}
trap cleanup EXIT

$DATASTORE_CLIENT --query "$query_create"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS $user"
$DATASTORE_CLIENT --query "CREATE USER $user"
$DATASTORE_CLIENT --query "GRANT SHOW DATABASES ON test_03821_db_1.*, SHOW DATABASES ON test_03821_db_2.*, SHOW DATABASES ON test_03821_db_3.*, SHOW DATABASES ON test_03821_db_4.*, SHOW DATABASES ON test_03821_db_5.* TO $user"

$DATASTORE_CLIENT --user "$user" --query "SELECT count() FROM system.databases WHERE name LIKE 'test\_03821\_db\_%'"
