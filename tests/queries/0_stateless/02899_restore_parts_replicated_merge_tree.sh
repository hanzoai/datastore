#!/usr/bin/env bash
# Tags: no-shared-merge-tree

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS table_with_unsuccessful_commits"

# will be flaky in 2031
$DATASTORE_CLIENT --query "CREATE TABLE table_with_unsuccessful_commits (key UInt64, value String) ENGINE ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/unsuccessful', '1') ORDER BY tuple() SETTINGS cleanup_delay_period=1000, max_cleanup_delay_period=1000, old_parts_lifetime = 1949748529, remove_rolled_back_parts_immediately=0, replicated_max_ratio_of_wrong_parts=1, max_suspicious_broken_parts=1000000, max_suspicious_broken_parts_bytes=10000000000"

$DATASTORE_CLIENT --query "INSERT INTO table_with_unsuccessful_commits SELECT rand(), toString(rand()) FROM numbers(10)"

$DATASTORE_CLIENT --query "INSERT INTO table_with_unsuccessful_commits SELECT rand(), toString(rand()) FROM numbers(10)"


for i in {0..10}; do
    $DATASTORE_CLIENT --query "OPTIMIZE TABLE table_with_unsuccessful_commits FINAL"
done

$DATASTORE_CLIENT --query "ALTER TABLE table_with_unsuccessful_commits DELETE WHERE value = 'hello' SETTINGS mutations_sync=2"
$DATASTORE_CLIENT --query "ALTER TABLE table_with_unsuccessful_commits DELETE WHERE value = 'hello' SETTINGS mutations_sync=2"

$DATASTORE_CLIENT --query "INSERT INTO table_with_unsuccessful_commits SELECT rand(), toString(rand()) FROM numbers(10)"

$DATASTORE_CLIENT --query "ALTER TABLE table_with_unsuccessful_commits DELETE WHERE value = 'hello' SETTINGS mutations_sync=2"

original_parts=$($DATASTORE_CLIENT --query "SELECT name FROM system.parts where table = 'table_with_unsuccessful_commits' and database = currentDatabase() and active order by name")

$DATASTORE_CLIENT --query "ALTER TABLE table_with_unsuccessful_commits MODIFY SETTING fault_probability_before_part_commit=1"

$DATASTORE_CLIENT --query "OPTIMIZE TABLE table_with_unsuccessful_commits FINAL SETTINGS alter_sync=0"

i=0 retries=300

while [[ $i -lt $retries ]]; do
    result=$($DATASTORE_CLIENT --query "SELECT last_exception FROM system.replication_queue WHERE table = 'table_with_unsuccessful_commits' and database=currentDatabase()")

    if [[ $result ]]; then
        break
    fi

    ((++i))
done

parts_after_mutation=$($DATASTORE_CLIENT --query "SELECT name FROM system.parts where table = 'table_with_unsuccessful_commits' and database = currentDatabase() and active order by name")

$DATASTORE_CLIENT --query "DETACH TABLE table_with_unsuccessful_commits"

$DATASTORE_CLIENT --query "ATTACH TABLE table_with_unsuccessful_commits"

parts_after_detach_attach=$($DATASTORE_CLIENT --query "SELECT name FROM system.parts where table = 'table_with_unsuccessful_commits' and database = currentDatabase() and active order by name")

if [[ "$parts_after_detach_attach" == "$parts_after_mutation" && "$parts_after_mutation" == "$original_parts" ]]; then
   echo "Ok"
else
    echo "Original parts $original_parts"
    echo "Parts after mutation $parts_after_mutation"
    echo "Parts after detach attach $parts_after_detach_attach"
fi

$DATASTORE_CLIENT --query "DROP TABLE table_with_unsuccessful_commits"
