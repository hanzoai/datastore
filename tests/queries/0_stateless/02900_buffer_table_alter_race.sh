#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "drop table if exists 02900_buffer"
$DATASTORE_CLIENT -q "drop table if exists 02900_destination"

$DATASTORE_CLIENT -q "create table 02900_destination (k Int8, v String) engine Memory"
$DATASTORE_CLIENT -q "create table 02900_buffer (k Int8) engine Buffer(currentDatabase(), '02900_destination', 1, 1000, 1000, 10000, 10000, 1000000, 1000000)"

$DATASTORE_CLIENT -q "insert into 02900_buffer (k) select 0"

# Start a long-running INSERT that uses the old schema.
$DATASTORE_CLIENT -q "insert into 02900_buffer (k) select sleepEachRow(1)+1 from numbers(5) settings max_block_size=1, max_insert_block_size=1, min_insert_block_size_rows=0, min_insert_block_size_bytes=0" &

sleep 1

$DATASTORE_CLIENT -q "alter table 02900_buffer add column v String"

$DATASTORE_CLIENT -q "insert into 02900_buffer (k, v) select 2, 'bobr'"

wait

# The data produced by the long-running INSERT after the ALTER is not visible until flushed.
$DATASTORE_CLIENT -q "select * from 02900_buffer where k != 1 order by k"

$DATASTORE_CLIENT -q "optimize table 02900_buffer"
$DATASTORE_CLIENT -q "select * from 02900_buffer order by k"

$DATASTORE_CLIENT -q "drop table 02900_buffer"
$DATASTORE_CLIENT -q "drop table 02900_destination"
