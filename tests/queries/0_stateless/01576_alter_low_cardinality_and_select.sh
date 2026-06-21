#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS alter_table"

${DATASTORE_CLIENT} --query "CREATE TABLE alter_table (key UInt64, value String) ENGINE MergeTree ORDER BY key"

# we don't need mutations and merges
${DATASTORE_CLIENT} --query "SYSTEM STOP MERGES alter_table"

${DATASTORE_CLIENT} --query "INSERT INTO alter_table SELECT number, toString(number) FROM numbers(10000)"
${DATASTORE_CLIENT} --query "INSERT INTO alter_table SELECT number, toString(number) FROM numbers(10000, 10000)"
${DATASTORE_CLIENT} --query "INSERT INTO alter_table SELECT number, toString(number) FROM numbers(20000, 10000)"

${DATASTORE_CLIENT} --query "SELECT * FROM alter_table WHERE value == '733'"

${DATASTORE_CLIENT} --query "ALTER TABLE alter_table MODIFY COLUMN value LowCardinality(String)" &

# waiting until schema will change (but not data)
show_query="SHOW CREATE TABLE alter_table"
create_query=""
while [[ "$create_query" != *"LowCardinality"* ]]
do
    sleep 0.1
    create_query=$($DATASTORE_CLIENT --query "$show_query")
done

# checking type is LowCardinality
${DATASTORE_CLIENT} --query "SHOW CREATE TABLE alter_table"

# checking no mutations happened
${DATASTORE_CLIENT} --query "SELECT name FROM system.parts where table='alter_table' and active and database='${DATASTORE_DATABASE}' ORDER BY name"

# checking that conversions applied "on fly" works
${DATASTORE_CLIENT} --query "SELECT * FROM alter_table PREWHERE key > 700 WHERE value = '701'"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS alter_table"
