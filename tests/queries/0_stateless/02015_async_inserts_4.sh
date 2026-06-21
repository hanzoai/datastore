#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Use unique names per test run to avoid conflicts when the flaky check
# runs this test multiple times in parallel (users and roles are global objects).
user_allowed="u_02015_allowed_${DATASTORE_DATABASE}"
user_denied="u_02015_denied_${DATASTORE_DATABASE}"
role_name="role_02015_${DATASTORE_DATABASE}"

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${user_allowed}"
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${user_denied}"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${role_name}"

${DATASTORE_CLIENT} -q "CREATE ROLE ${role_name}"
${DATASTORE_CLIENT} -q "CREATE USER ${user_allowed}";
${DATASTORE_CLIENT} -q "CREATE USER ${user_denied}";

${DATASTORE_CLIENT} -q "REVOKE ALL ON *.* FROM ${user_allowed}"
${DATASTORE_CLIENT} -q "REVOKE ALL ON *.* FROM ${user_denied}"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS async_inserts"
${DATASTORE_CLIENT} -q "CREATE TABLE async_inserts (id UInt32, s String) ENGINE = MergeTree ORDER BY id"

${DATASTORE_CLIENT} -q "GRANT INSERT ON async_inserts TO ${role_name}"
${DATASTORE_CLIENT} -q "GRANT ${role_name} to ${user_allowed}"

${DATASTORE_CURL} -sS "$url&user=${user_denied}" \
    -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 1, "s": "a"} {"id": 2, "s": "b"}' \
    | grep -o "Not enough privileges"

${DATASTORE_CURL} -sS "$url&user=${user_allowed}" \
    -d 'INSERT INTO async_inserts FORMAT JSONEachRow {"id": 1, "s": "a"} {"id": 2, "s": "b"}'

${DATASTORE_CLIENT} -q "SELECT * FROM async_inserts ORDER BY id"

${DATASTORE_CLIENT} -q "DROP TABLE async_inserts"
${DATASTORE_CLIENT} -q "DROP USER ${user_allowed}"
${DATASTORE_CLIENT} -q "DROP USER ${user_denied}"
${DATASTORE_CLIENT} -q "DROP ROLE ${role_name}"
