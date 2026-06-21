#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user_name="u_03168_query_log_${DATASTORE_DATABASE}"
table_name="d_03168_query_log"
test_query="select a, b from ${table_name}"

${DATASTORE_CLIENT} --query "drop user if exists ${user_name}"
${DATASTORE_CLIENT} --query "create user ${user_name}"
${DATASTORE_CLIENT} --query "drop table if exists ${table_name}"
${DATASTORE_CLIENT} --query "create table ${table_name} (a UInt64, b UInt64) order by a"
${DATASTORE_CLIENT} --query "insert into table ${table_name} values (3168, 8613)"

${DATASTORE_CLIENT} --user ${user_name} --query "${test_query}" 2>&1 >/dev/null | (grep -q "ACCESS_DENIED" || echo "Expected ACCESS_DENIED error not found")

${DATASTORE_CLIENT} --query "grant select(a, b) on ${table_name} to ${user_name}"
${DATASTORE_CLIENT} --user ${user_name} --query "${test_query}"

${DATASTORE_CLIENT} --query "system flush logs query_log"
${DATASTORE_CLIENT} --query "select used_privileges, missing_privileges from system.query_log where event_date >= yesterday() AND event_time >= now() - 600 AND query = '${test_query}' and type = 'ExceptionBeforeStart' and current_database = currentDatabase() order by event_time desc limit 1"
${DATASTORE_CLIENT} --query "select used_privileges, missing_privileges from system.query_log where event_date >= yesterday() AND event_time >= now() - 600 AND query = '${test_query}' and type = 'QueryStart' and current_database = currentDatabase() order by event_time desc limit 1"
${DATASTORE_CLIENT} --query "select used_privileges, missing_privileges from system.query_log where event_date >= yesterday() AND event_time >= now() - 600 AND query = '${test_query}' and type = 'QueryFinish' and current_database = currentDatabase() order by event_time desc limit 1"

${DATASTORE_CLIENT} --query "drop table ${table_name}"
${DATASTORE_CLIENT} --query "drop user ${user_name}"
