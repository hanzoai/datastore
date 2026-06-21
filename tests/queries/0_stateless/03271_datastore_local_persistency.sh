#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

cd "${DATASTORE_TMP}" || exit
rm -rf "datastore.local"
rm -f test

# You can specify the path explicitly.
$DATASTORE_LOCAL --path "datastore.local" --query "SELECT 1"

# You can create tables.
$DATASTORE_LOCAL --path "datastore.local" --query "CREATE TABLE test (x UInt64, s String) ENGINE = MergeTree ORDER BY x"

# The data is persisted between restarts
$DATASTORE_LOCAL --path "datastore.local" --query "INSERT INTO test SELECT number, 'Hello' || number FROM numbers(10)"
$DATASTORE_LOCAL --path "datastore.local" --query "SELECT * FROM test ORDER BY x"

# The default database is an Overlay on top of Atomic, which lets you exchange tables.
$DATASTORE_LOCAL --path "datastore.local" --query "SELECT name, engine FROM system.databases WHERE name = 'default'"
$DATASTORE_LOCAL --path "datastore.local" --query "CREATE OR REPLACE TABLE test (s String) ENGINE = MergeTree ORDER BY ()"
$DATASTORE_LOCAL --path "datastore.local" --query "SELECT * FROM test"
$DATASTORE_LOCAL --path "datastore.local" --query "INSERT INTO test SELECT 'World' || number FROM numbers(10)"
$DATASTORE_LOCAL --path "datastore.local" --query "SELECT * FROM test"

# It is an overlay database. If you don't have a table with the same name, it will look for a file with that name.
# Files are searched relative to the current working directory.
echo '"Hello"
"World"' > "test"

echo
$DATASTORE_LOCAL --path "datastore.local" --query "SELECT * FROM test; DROP TABLE test; SELECT * FROM test;"

rm -rf "datastore.local"
rm test
