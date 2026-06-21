#!/usr/bin/env bash
# Tags: long, zookeeper

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_rename_replicated"

$DATASTORE_CLIENT --query "
CREATE TABLE table_for_rename_replicated
(
  date Date,
  key UInt64,
  value1 String,
  value2 String,
  value3 String
)
ENGINE = ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/table_for_rename_replicated', '1')
PARTITION BY date
ORDER BY key;
"


$DATASTORE_CLIENT --query "INSERT INTO table_for_rename_replicated SELECT toDate('2019-10-01') + number % 3, number, toString(number), toString(number), toString(number) from numbers(9);"

$DATASTORE_CLIENT --query "SELECT value1 FROM table_for_rename_replicated WHERE key = 1;"

$DATASTORE_CLIENT --query "SYSTEM STOP MERGES table_for_rename_replicated;"

$DATASTORE_CLIENT --query "SHOW CREATE TABLE table_for_rename_replicated;"

$DATASTORE_CLIENT --query "ALTER TABLE table_for_rename_replicated RENAME COLUMN value1 to renamed_value1" --replication_alter_partitions_sync=0


while [[ -z $($DATASTORE_CLIENT --query "SELECT name FROM system.columns WHERE name = 'renamed_value1' and table = 'table_for_rename_replicated' AND database = '$DATASTORE_DATABASE'" 2>/dev/null) ]]; do
    sleep 0.5
done

$DATASTORE_CLIENT --query "SELECT name FROM system.columns WHERE name = 'renamed_value1' and table = 'table_for_rename_replicated' AND database = '$DATASTORE_DATABASE'"

# SHOW CREATE TABLE takes query from .sql file on disk.
# previous select take metadata from memory. So, when previous select says, that return renamed_value1 already exists in table, it's still can have old version on disk.
while [[ -z $($DATASTORE_CLIENT --query "SHOW CREATE TABLE table_for_rename_replicated;" | grep 'renamed_value1') ]]; do
    sleep 0.5
done

$DATASTORE_CLIENT --query "SHOW CREATE TABLE table_for_rename_replicated;"

$DATASTORE_CLIENT --query "SELECT renamed_value1 FROM table_for_rename_replicated WHERE key = 1;"

$DATASTORE_CLIENT --query "SELECT * FROM table_for_rename_replicated WHERE key = 1 FORMAT TSVWithNames;"

$DATASTORE_CLIENT --query "SYSTEM START MERGES table_for_rename_replicated;"

$DATASTORE_CLIENT --query "SYSTEM SYNC REPLICA table_for_rename_replicated;"

$DATASTORE_CLIENT --query "SELECT * FROM table_for_rename_replicated WHERE key = 1 FORMAT TSVWithNames;"

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_rename_replicated;"
