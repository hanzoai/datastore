#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

user=user_$DATASTORE_TEST_UNIQUE_NAME
$DATASTORE_CLIENT --query "DROP USER IF EXISTS $user"
$DATASTORE_CLIENT --query "CREATE USER $user IDENTIFIED WITH PLAINTEXT_PASSWORD BY 'hello'"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_memory_02561(name String)" 2>&1 | grep -F "Not enough privileges. To execute this query, it's necessary to have the grant CREATE TEMPORARY TABLE" > /dev/null && echo "OK"

$DATASTORE_CLIENT --query "GRANT CREATE TEMPORARY TABLE ON *.* TO $user"
$DATASTORE_CLIENT --query "GRANT TABLE ENGINE ON Memory TO $user"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_memory_02561(name String)"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_merge_tree_02561(name String) ENGINE = MergeTree() ORDER BY name" 2>&1 | grep -F "Not enough privileges. To execute this query, it's necessary to have the grant CREATE ARBITRARY TEMPORARY TABLE" > /dev/null && echo "OK"

$DATASTORE_CLIENT --query "GRANT CREATE ARBITRARY TEMPORARY TABLE ON *.* TO $user"
$DATASTORE_CLIENT --query "GRANT TABLE ENGINE ON MergeTree TO $user"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_merge_tree_02561(name String) ENGINE = MergeTree() ORDER BY name"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_file_02561(name String) ENGINE = File(TabSeparated)" 2>&1 | grep -F "Not enough privileges." > /dev/null && echo "OK"

$DATASTORE_CLIENT --query "GRANT READ, WRITE ON File TO $user"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_file_02561(name String) ENGINE = File(TabSeparated)"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_url_02561(name String) ENGINE = URL('http://127.0.0.1:8123?query=select+12', 'RawBLOB')" 2>&1 | grep -F "Not enough privileges." > /dev/null && echo "OK"

$DATASTORE_CLIENT --query "GRANT READ, WRITE ON URL TO $user"

$DATASTORE_CLIENT --user $user --password hello --query "CREATE TEMPORARY TABLE table_url_02561(name String) ENGINE = URL('http://127.0.0.1:8123?query=select+12', 'RawBLOB')"

$DATASTORE_CLIENT --query "DROP USER $user"
