#!/usr/bin/env bash
# Tags: no-fasttest, no-random-settings, no-random-merge-tree-settings, no-encrypted-storage
# Tag no-fasttest: requires S3
# Tag no-random-settings, no-random-merge-tree-settings: to avoid creating extra files like serialization.json, this test too exocit anyway

# Creation of a database with Ordinary engine emits a warning.
DATASTORE_CLIENT_SERVER_LOGS_LEVEL=fatal

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# config for datastore-disks (to check leftovers)
config="${CUR_DIR}/02980_s3_plain_DROP_TABLE_MergeTree.yml"

# only in Atomic ATTACH from s3_plain works
new_database="ordinary_$DATASTORE_DATABASE"
$DATASTORE_CLIENT --allow_deprecated_database_ordinary=1 -q "create database $new_database engine=Ordinary"
DATASTORE_CLIENT=${DATASTORE_CLIENT/--database=$DATASTORE_DATABASE/--database=$new_database}
DATASTORE_DATABASE="$new_database"

$DATASTORE_CLIENT -m -q "
    drop table if exists data;
    create table data (key Int) engine=MergeTree() order by key settings write_marks_for_substreams_in_compact_parts=1, auto_statistics_types = '';
    insert into data values (1);
    select 'data after INSERT', count() from data;
"

# suppress output
$DATASTORE_CLIENT -q "backup table data to S3('http://localhost:11111/test/s3_plain/backups/$DATASTORE_DATABASE', 'test', 'testtest')" > /dev/null

$DATASTORE_CLIENT -m -q "
    drop table data;
    attach table data (key Int) engine=MergeTree() order by key
    settings
        max_suspicious_broken_parts=0,
        write_marks_for_substreams_in_compact_parts=1,
        disk=disk(type=s3_plain,
            endpoint='http://localhost:11111/test/s3_plain/backups/$DATASTORE_DATABASE',
            access_key_id='test',
            secret_access_key='testtest');
    select 'data after ATTACH', count() from data;

    insert into data values (1); -- { serverError TABLE_IS_READ_ONLY }
    optimize table data final; -- { serverError TABLE_IS_READ_ONLY }
"

path=$($DATASTORE_CLIENT -q "SELECT replace(data_paths[1], 's3_plain', '') FROM system.tables WHERE database = '$DATASTORE_DATABASE' AND table = 'data'")
# trim / to fix "Unable to parse ExceptionName: XMinioInvalidObjectName Message: Object name contains unsupported characters."
path=${path%/}

echo "Files before DETACH TABLE"
datastore-disks -C "$config" --disk s3_plain_disk --query "list --recursive $path" | tail -n+2

$DATASTORE_CLIENT -q "detach table data"
echo "Files after DETACH TABLE"
datastore-disks -C "$config" --disk s3_plain_disk --query "list --recursive $path" | tail -n+2

# metadata file is left
$DATASTORE_CLIENT --force_remove_data_recursively_on_drop=1 -q "drop database if exists $DATASTORE_DATABASE"
