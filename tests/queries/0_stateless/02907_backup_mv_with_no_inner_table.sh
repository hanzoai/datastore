#!/usr/bin/env bash
# Tags: no-ordinary-database

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} -m --query "
drop table if exists src;
create table src (a Int32) engine = MergeTree() order by tuple();

drop table if exists mv;
create materialized view mv (a Int32) engine = MergeTree() order by tuple() as select * from src;
"

uuid=$(${DATASTORE_CLIENT} --query "select uuid from system.tables where table='mv' and database == currentDatabase()")
inner_table=".inner_id.${uuid}"
${DATASTORE_CLIENT} -m --query "drop table \`$inner_table\` sync"

${DATASTORE_CLIENT} -m --query "
set send_logs_level = 'error';
backup table ${DATASTORE_DATABASE}.\`mv\` to Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}');
" | grep -o "BACKUP_CREATED"

${DATASTORE_CLIENT} -m --query "
drop table mv;
restore table ${DATASTORE_DATABASE}.\`mv\` from Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}');
" | grep -o "RESTORED"

${DATASTORE_CLIENT} --query "select count() from mv;"
