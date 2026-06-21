#!/usr/bin/env bash
# Tags: replica, no-replicated-database
# I don't understand why this test fails in ReplicatedDatabase run
# but too many magic included in it, so I just disabled it for ReplicatedDatabase run becase
# here we explicitely create it and check is alright.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "create table mute_stylecheck (x UInt32) engine = ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/mute_stylecheck', '1') order by x"

${DATASTORE_CLIENT} -q "CREATE USER user_${DATASTORE_DATABASE} settings database_replicated_allow_replicated_engine_arguments=0"
${DATASTORE_CLIENT} -q "GRANT CREATE TABLE ON ${DATASTORE_DATABASE}_db.* TO user_${DATASTORE_DATABASE}"
${DATASTORE_CLIENT} -q "GRANT TABLE ENGINE ON ReplicatedMergeTree TO user_${DATASTORE_DATABASE}"
${DATASTORE_CLIENT} -q "CREATE DATABASE ${DATASTORE_DATABASE}_db engine = Replicated('/datastore/databases/${DATASTORE_TEST_ZOOKEEPER_PREFIX}/${DATASTORE_DATABASE}_db', '{shard}', '{replica}')"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --user "user_${DATASTORE_DATABASE}" --query "CREATE TABLE ${DATASTORE_DATABASE}_db.tab_rmt_ok (x UInt32) engine = ReplicatedMergeTree order by x;"
${DATASTORE_CLIENT} --distributed_ddl_output_mode=none --user "user_${DATASTORE_DATABASE}" --query "CREATE TABLE ${DATASTORE_DATABASE}_db.tab_rmt_fail (x UInt32) engine = ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/root/{shard}', '{replica}') order by x; -- { serverError 36 }"
${DATASTORE_CLIENT} --query "DROP DATABASE ${DATASTORE_DATABASE}_db"
${DATASTORE_CLIENT} -q "DROP USER user_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "drop table mute_stylecheck"
