#!/usr/bin/env bash
# Tags: no-object-storage, no-random-settings, no-random-merge-tree-settings

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -m -q "
    drop table if exists data;
    create table data (key UInt64 CODEC(NONE)) engine=MergeTree() order by tuple() settings min_bytes_for_wide_part=1e9;
"

# reading 1e6*8 bytes with 1M bandwith it should take (8-1)/1=7 seconds
$DATASTORE_CLIENT -q "insert into data select * from numbers(1e6)"

query_id=$(random_str 10)
$DATASTORE_CLIENT --query_id "$query_id" -q "backup table data to Disk('backups', '$DATASTORE_DATABASE/data/backup1') SETTINGS max_backup_bandwidth=1e6" > /dev/null
$DATASTORE_CLIENT -m -q "
    SYSTEM FLUSH LOGS query_log;
    SELECT
        query_duration_ms >= 7e3,
        ProfileEvents['ReadBufferFromFileDescriptorReadBytes'] > 8e6
    FROM system.query_log
    WHERE event_date >= yesterday() AND event_time >= now() - 600 AND current_database = '$DATASTORE_DATABASE' AND query_id = '$query_id' AND type != 'QueryStart'
"
