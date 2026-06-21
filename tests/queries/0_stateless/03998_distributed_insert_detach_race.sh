#!/usr/bin/env bash
# Tags: long, no-s3-storage

# Stress test for the race between async INSERT into Distributed and DETACH.
# Before the fix, this could cause "Cannot schedule a file" LOGICAL_ERROR.

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -nmq "
    DROP TABLE IF EXISTS dist_03998;
    DROP TABLE IF EXISTS local_03998;
    CREATE TABLE local_03998 (x UInt64) ENGINE = Null;
    CREATE TABLE dist_03998 (x UInt64) ENGINE = Distributed(test_cluster_two_shards, currentDatabase(), local_03998, x);
"

function insert_thread()
{
    for _ in {1..100}; do
        ${DATASTORE_CURL} -sfS "$DATASTORE_URL&distributed_foreground_insert=0&prefer_localhost_replica=0" -d "INSERT INTO dist_03998 VALUES (1)(2)" >& /dev/null
    done
}

function detach_attach_thread()
{
    # Small delay to do some INSERTs just in case
    sleep 0.3
    for _ in {1..100}; do
        ${DATASTORE_CURL} -sfS "$DATASTORE_URL" -d "DETACH TABLE dist_03998" >& /dev/null
        ${DATASTORE_CURL} -sfS "$DATASTORE_URL" -d "ATTACH TABLE dist_03998" >& /dev/null
    done
}

insert_thread &
detach_attach_thread &

wait

# Reattach in case the table was left detached
$DATASTORE_CLIENT -q "ATTACH TABLE dist_03998" 2>/dev/null

$DATASTORE_CLIENT -nmq "
    DROP TABLE dist_03998;
    DROP TABLE local_03998;
"
