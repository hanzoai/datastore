#!/usr/bin/env bash

DATASTORE_CLIENT_SERVER_LOGS_LEVEL=none

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

USER=u_01889$RANDOM
ROLE=r_01889$RANDOM
POLICY=t_01889_filter$RANDOM

${DATASTORE_CLIENT} -q "drop user if exists $USER"
${DATASTORE_CLIENT} -q "drop role if exists ${ROLE}"
${DATASTORE_CLIENT} -q "drop policy if exists ${POLICY} on t_01889"
${DATASTORE_CLIENT} -q "create user $USER identified with plaintext_password by 'dfsdffdf5t123'"
${DATASTORE_CLIENT} -q "revoke all on *.* from $USER"
${DATASTORE_CLIENT} -q "create role ${ROLE}"
${DATASTORE_CLIENT} -q "create table t_01889(a Int64, user_id String) Engine=MergeTree order by a"
${DATASTORE_CLIENT} -q "insert into t_01889 select number, '$USER' from numbers(1000)"
${DATASTORE_CLIENT} -q "insert into t_01889 select number, 'xxxxxxx' from numbers(1000)"
${DATASTORE_CLIENT} -q "grant select on t_01889 to ${ROLE}"
${DATASTORE_CLIENT} -q "create row policy ${POLICY} ON t_01889 FOR SELECT USING user_id = user() TO ${ROLE}"
${DATASTORE_CLIENT} -q "grant ${ROLE} to $USER"
${DATASTORE_CLIENT} -q "alter user $USER default role ${ROLE} settings none"

${DATASTORE_CLIENT_BINARY} --database=${DATASTORE_DATABASE} --user=$USER --password=dfsdffdf5t123 --query="select count() from t_01889"

${DATASTORE_CLIENT} -q "drop user $USER"
${DATASTORE_CLIENT} -q "drop policy ${POLICY} on t_01889"
${DATASTORE_CLIENT} -q "drop role ${ROLE}"
${DATASTORE_CLIENT} -q "drop table t_01889"
