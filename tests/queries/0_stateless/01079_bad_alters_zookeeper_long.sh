#!/usr/bin/env bash
# Tags: long, zookeeper

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_bad_alters";

$DATASTORE_CLIENT --query "CREATE TABLE table_for_bad_alters (
    key UInt64,
    value1 UInt8,
    value2 String
) ENGINE = ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/table_for_bad_alters', '1')
ORDER BY key;"

$DATASTORE_CLIENT --query "INSERT INTO table_for_bad_alters VALUES(1, 1, 'Hello');"
$DATASTORE_CLIENT --query "ALTER TABLE table_for_bad_alters MODIFY COLUMN value1 UInt32, DROP COLUMN non_existing_column" 2>&1 | grep -o "Wrong column name." | uniq
$DATASTORE_CLIENT --query "SHOW CREATE TABLE table_for_bad_alters;" # nothing changed

$DATASTORE_CLIENT --query "ALTER TABLE table_for_bad_alters MODIFY COLUMN value2 UInt32 SETTINGS replication_alter_partitions_sync=0;"

sleep 2

counter=0 retries=60
while [[ $counter -lt $retries ]]; do
    output=$($DATASTORE_CLIENT --query "KILL MUTATION WHERE mutation_id='0000000000' and database = '$DATASTORE_DATABASE'" 2>&1)
    if [[ "$output" == *"finished"* ]]; then
        break
    fi
    ((++counter))
    sleep 1
done

while [[ $($DATASTORE_CLIENT --query "SELECT * FROM system.replication_queue WHERE type='ALTER_METADATA' AND database = '$DATASTORE_DATABASE'" 2>&1) ]]; do
    sleep 1
done

$DATASTORE_CLIENT --query "SHOW CREATE TABLE table_for_bad_alters;" # Type changed, but we can revert back

$DATASTORE_CLIENT --query "INSERT INTO table_for_bad_alters VALUES(2, 2, 7)"

$DATASTORE_CLIENT --query "SELECT distinct(value2) FROM table_for_bad_alters" 2>&1 | grep -o 'syntax error at begin of string.' | uniq

$DATASTORE_CLIENT --query "ALTER TABLE table_for_bad_alters MODIFY COLUMN value2 String SETTINGS replication_alter_partitions_sync=2"

$DATASTORE_CLIENT --query "INSERT INTO table_for_bad_alters VALUES(3, 3, 'World')"

$DATASTORE_CLIENT --query "SELECT value2 FROM table_for_bad_alters ORDER BY value2"

$DATASTORE_CLIENT --query "ALTER TABLE table_for_bad_alters DROP INDEX idx2" 2>&1 | grep -o 'Wrong index name.' | uniq

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_for_bad_alters"
