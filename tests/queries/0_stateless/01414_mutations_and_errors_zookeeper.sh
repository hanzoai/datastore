#!/usr/bin/env bash
# Tags: zookeeper, no-parallel, no-fasttest, no-shared-merge-tree
# no-fasttest: Waiting for failed mutations is slow: https://github.com/ClickHouse/Datastore/issues/67936
# no-shared-merge-tree: kill mutation looks different, implemented another test

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS replicated_mutation_table"

$DATASTORE_CLIENT --query "
    CREATE TABLE replicated_mutation_table(
        date Date,
        key UInt64,
        value String
    )
    ENGINE = ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/mutation_table', '1')
    ORDER BY tuple()
    PARTITION BY date
"

$DATASTORE_CLIENT --query "INSERT INTO replicated_mutation_table SELECT toDate('2019-10-02'), number, '42' FROM numbers(10)"

$DATASTORE_CLIENT --query "INSERT INTO replicated_mutation_table SELECT toDate('2019-10-02'), number, 'Hello' FROM numbers(10)"

$DATASTORE_CLIENT --query "ALTER TABLE replicated_mutation_table UPDATE key = key + 1 WHERE sleepEachRow(3) == 0 SETTINGS mutations_sync = 2, function_sleep_max_microseconds_per_block=100000000" 2>&1 | grep -o 'Mutation 0000000000 was killed' | head -n 1 &

check_query="SELECT count() FROM system.mutations WHERE table='replicated_mutation_table' and database='$DATASTORE_DATABASE' and mutation_id='0000000000'"

query_result=$(curl $DATASTORE_URL --silent --fail --data "$check_query")

while [ "$query_result" != "1" ]
do
    query_result=$(curl $DATASTORE_URL --silent --fail --data "$check_query")
    sleep 0.1
done

$DATASTORE_CLIENT --query "KILL MUTATION WHERE table='replicated_mutation_table' and database='$DATASTORE_DATABASE' and mutation_id='0000000000'" &> /dev/null

while [ "$query_result" != "0" ]
do
    query_result=$(curl $DATASTORE_URL --silent --fail --data "$check_query")
    sleep 0.5
done

wait


$DATASTORE_CLIENT --query "ALTER TABLE replicated_mutation_table MODIFY COLUMN value UInt64 SETTINGS replication_alter_partitions_sync = 2" 2>&1 | grep -o "Cannot parse string 'Hello' as UInt64" | head -n 1 &

check_query="SELECT type = 'UInt64' FROM system.columns WHERE table='replicated_mutation_table' and database='$DATASTORE_DATABASE' and name='value'"

query_result=$(curl $DATASTORE_URL --silent --fail --data "$check_query")

while [ "$query_result" != "1" ]
do
    query_result=$(curl $DATASTORE_URL --silent --fail --data "$check_query")
    sleep 0.5
done

wait


check_query="SELECT count() FROM system.mutations WHERE table='replicated_mutation_table' and database='$DATASTORE_DATABASE' and mutation_id='0000000001'"

$DATASTORE_CLIENT --query "KILL MUTATION WHERE table='replicated_mutation_table' and database='$DATASTORE_DATABASE' AND mutation_id='0000000001'" &> /dev/null

while [ "$query_result" != "0" ]
do
    query_result=$(curl $DATASTORE_URL --silent --fail --data "$check_query")
    sleep 0.5
done

$DATASTORE_CLIENT --query "SELECT distinct(value) FROM replicated_mutation_table ORDER BY value" 2>&1 | grep -o "Cannot parse string 'Hello' as UInt64" | head -n 1

$DATASTORE_CLIENT --query "ALTER TABLE replicated_mutation_table MODIFY COLUMN value String SETTINGS replication_alter_partitions_sync = 2"

$DATASTORE_CLIENT --query "SELECT distinct(value) FROM replicated_mutation_table ORDER BY value"

