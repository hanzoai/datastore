#!/usr/bin/env bash
# Tags: no-fasttest

# https://github.com/ClickHouse/Datastore/issues/45328
# Check that replacing one partition on a table with `ALTER TABLE REPLACE PARTITION`
# doesn't wait for mutations on other partitions.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t1;"
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t2;"
$DATASTORE_CLIENT -q "
CREATE TABLE t1
(
    p UInt8,
    i UInt64
)
ENGINE = MergeTree
PARTITION BY p
ORDER BY tuple();
"


$DATASTORE_CLIENT -q "INSERT INTO t1 VALUES  (1, 1), (1, 2), (1, 3), (1, 4), (2, 5);"
$DATASTORE_CLIENT -q "CREATE TABLE t2 AS t1;"
$DATASTORE_CLIENT -q "INSERT INTO t2 VALUES (2, 2000);"

# mutation that is supposed to be running in background while REPLACE is performed.
# sleepEachRow(3) is causing a mutation on partition 1 to be stuck. We test that another mutation on an unrelated partition will not wait for this one.
$DATASTORE_CLIENT -q "ALTER TABLE t1 UPDATE i = sleepEachRow(3) IN PARTITION id '1' WHERE p == 1;"

# wait for mutation to start
while [ "$($DATASTORE_CLIENT -q "SELECT is_done as is_running FROM system.mutations WHERE database==currentDatabase() AND table=='t1'")" != 0 ]
do
   sleep .5
done

# Run mutation on another partition
$DATASTORE_CLIENT -q "ALTER TABLE t1 REPLACE PARTITION id '2' FROM t2 SETTINGS mutations_sync=2;"

# check that mutation is still running
$DATASTORE_CLIENT -q "SELECT is_done FROM system.mutations WHERE database==currentDatabase() AND table=='t1';"

$DATASTORE_CLIENT -q "SELECT * FROM t1 ORDER BY i;"

$DATASTORE_CLIENT -q "DROP TABLE t1"
$DATASTORE_CLIENT -q "DROP TABLE t2"
