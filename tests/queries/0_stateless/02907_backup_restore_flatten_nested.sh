#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} -m --query "
drop table if exists test;
set flatten_nested = 0;
create table test (test Array(Tuple(foo String, bar Float64))) ENGINE = MergeTree() ORDER BY tuple();
backup table ${DATASTORE_DATABASE}.test on cluster test_shard_localhost to Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}');
" | grep -o "BACKUP_CREATED"

${DATASTORE_CLIENT} --query "show create table test"

${DATASTORE_CLIENT} -m --query "
drop table if exists test2;
set flatten_nested = 0;
create table test2 (test Nested(foo String, bar Float64)) ENGINE = MergeTree() ORDER BY tuple();
backup table ${DATASTORE_DATABASE}.test2 on cluster test_shard_localhost to Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}2');
" | grep -o "BACKUP_CREATED"

${DATASTORE_CLIENT} --query "show create table test2"

${DATASTORE_CLIENT} -m --query "
drop table test sync;
set flatten_nested = 1;
restore table ${DATASTORE_DATABASE}.test on cluster test_shard_localhost from Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}');
" | grep -o "RESTORED"

${DATASTORE_CLIENT} --query "show create table test"

${DATASTORE_CLIENT} -m --query "
drop table test2 sync;
set flatten_nested = 1;
restore table ${DATASTORE_DATABASE}.test2 on cluster test_shard_localhost from Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}2');
" | grep -o "RESTORED"

${DATASTORE_CLIENT} --query "show create table test2"
