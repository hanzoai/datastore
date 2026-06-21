#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} -m --query "
drop table if exists test;
set data_type_default_nullable = 0;
create table test (test String) ENGINE = MergeTree() ORDER BY tuple();
backup table ${DATASTORE_DATABASE}.test on cluster test_shard_localhost to Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}');
" | grep -o "BACKUP_CREATED"

${DATASTORE_CLIENT} --query "show create table test"

${DATASTORE_CLIENT} -m --query "
drop table test sync;
set data_type_default_nullable = 1;
restore table ${DATASTORE_DATABASE}.test on cluster test_shard_localhost from Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}');
" | grep -o "RESTORED"

${DATASTORE_CLIENT} --query "show create table test"
