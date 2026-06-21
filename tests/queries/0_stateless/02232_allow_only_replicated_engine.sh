#!/usr/bin/env bash
# Tags: replica

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "create table mute_stylecheck (x UInt32) engine = ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/root', '1') order by x"

${DATASTORE_CLIENT} -q "CREATE USER user_${DATASTORE_DATABASE} settings database_replicated_allow_only_replicated_engine=1"
${DATASTORE_CLIENT} -q "GRANT CREATE TABLE ON ${DATASTORE_DATABASE}_db.* TO user_${DATASTORE_DATABASE}"
${DATASTORE_CLIENT} -q "GRANT TABLE ENGINE ON Memory, TABLE ENGINE ON MergeTree, TABLE ENGINE ON ReplicatedMergeTree TO user_${DATASTORE_DATABASE}"
${DATASTORE_CLIENT} -q "CREATE DATABASE ${DATASTORE_DATABASE}_db engine = Replicated('/datastore/databases/${DATASTORE_TEST_ZOOKEEPER_PREFIX}/${DATASTORE_DATABASE}_db', '{shard}', '{replica}')"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --user "user_${DATASTORE_DATABASE}" --query "CREATE TABLE ${DATASTORE_DATABASE}_db.tab_memory (x UInt32) engine = Memory;"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --user "user_${DATASTORE_DATABASE}" --query "CREATE TABLE ${DATASTORE_DATABASE}_db.tab_mt (x UInt32) engine = MergeTree order by x;" 2>&1 | grep -o "Only tables with a Replicated engine"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --query "CREATE TABLE ${DATASTORE_DATABASE}_db.tab_mt (x UInt32) engine = MergeTree order by x;"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --user "user_${DATASTORE_DATABASE}" --query "CREATE TABLE ${DATASTORE_DATABASE}_db.tab_rmt (x UInt32) engine = ReplicatedMergeTree order by x;"
${DATASTORE_CLIENT} --query "DROP DATABASE ${DATASTORE_DATABASE}_db"
${DATASTORE_CLIENT} -q "DROP USER user_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "drop table mute_stylecheck"
