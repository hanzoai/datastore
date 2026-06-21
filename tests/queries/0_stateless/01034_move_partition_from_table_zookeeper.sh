#!/usr/bin/env bash
# Tags: zookeeper, no-fasttest

DATASTORE_CLIENT_SERVER_LOGS_LEVEL=none

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS src;"
$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS dst;"

$DATASTORE_CLIENT --query="CREATE TABLE src (p UInt64, k String, d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/src1', '1') PARTITION BY p ORDER BY k;"
$DATASTORE_CLIENT --query="CREATE TABLE dst (p UInt64, k String, d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/dst1', '1') PARTITION BY p ORDER BY k
SETTINGS old_parts_lifetime=1, cleanup_delay_period=1, cleanup_delay_period_random_add=0, cleanup_thread_preferred_points_per_iteration=0;"

$DATASTORE_CLIENT --query="INSERT INTO src VALUES (0, '0', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (1, '0', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (1, '1', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (2, '0', 1);"

$DATASTORE_CLIENT --query="SELECT 'Initial';"
$DATASTORE_CLIENT --query="INSERT INTO dst VALUES (0, '1', 2);"
$DATASTORE_CLIENT --query="INSERT INTO dst VALUES (1, '1', 2), (1, '2', 2);"
$DATASTORE_CLIENT --query="INSERT INTO dst VALUES (2, '1', 2);"

$DATASTORE_CLIENT --query="SYSTEM SYNC REPLICA dst;"
$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM src;"
$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM dst;"


$DATASTORE_CLIENT --query="SELECT 'MOVE simple';"
query_with_retry "ALTER TABLE src MOVE PARTITION 1 TO TABLE dst;"

$DATASTORE_CLIENT --query="SYSTEM SYNC REPLICA dst;"
$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM src;"
$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM dst;"

$DATASTORE_CLIENT --query="DROP TABLE src;"
$DATASTORE_CLIENT --query="DROP TABLE dst;"

$DATASTORE_CLIENT --query="SELECT 'MOVE incompatible schema missing column';"

$DATASTORE_CLIENT --query="CREATE TABLE src (p UInt64, k String, d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/src2', '1') PARTITION BY p ORDER BY (d, p);"
$DATASTORE_CLIENT --query="CREATE TABLE dst (p UInt64, d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/dst2', '1') PARTITION BY p ORDER BY (d, p)
SETTINGS old_parts_lifetime=1, cleanup_delay_period=1, cleanup_delay_period_random_add=0, cleanup_thread_preferred_points_per_iteration=0;"

$DATASTORE_CLIENT --query="INSERT INTO src VALUES (0, '0', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (1, '0', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (1, '1', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (2, '0', 1);"

query_with_retry "ALTER TABLE src MOVE PARTITION 1 TO TABLE dst;" &>/dev/null
$DATASTORE_CLIENT --query="SYSTEM SYNC REPLICA dst;"

$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM src;"
$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM dst;"

$DATASTORE_CLIENT --query="DROP TABLE src;"
$DATASTORE_CLIENT --query="DROP TABLE dst;"

$DATASTORE_CLIENT --query="SELECT 'MOVE incompatible schema different order by';"

$DATASTORE_CLIENT --query="CREATE TABLE src (p UInt64, k String, d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/src3', '1') PARTITION BY p ORDER BY (p, k, d);"
$DATASTORE_CLIENT --query="CREATE TABLE dst (p UInt64, k String, d UInt64) ENGINE = ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/dst3', '1') PARTITION BY p ORDER BY (d, k, p);"


$DATASTORE_CLIENT --query="INSERT INTO src VALUES (0, '0', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (1, '0', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (1, '1', 1);"
$DATASTORE_CLIENT --query="INSERT INTO src VALUES (2, '0', 1);"

query_with_retry "ALTER TABLE src MOVE PARTITION 1 TO TABLE dst;" &>/dev/null
$DATASTORE_CLIENT --query="SYSTEM SYNC REPLICA dst;"

$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM src;"
$DATASTORE_CLIENT --query="SELECT count(), sum(d) FROM dst;"

$DATASTORE_CLIENT --query="DROP TABLE src;"
$DATASTORE_CLIENT --query="DROP TABLE dst;"

