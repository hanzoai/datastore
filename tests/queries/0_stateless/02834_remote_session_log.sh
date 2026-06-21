#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

readonly PID=$$
readonly TEST_USER=$"02834_USER_${PID}"
readonly SESSION_LOG_MATCHING_FIELDS="auth_id, auth_type, client_version_major, client_version_minor, client_version_patch, interface"

${DATASTORE_CLIENT} -q "CREATE USER IF NOT EXISTS ${TEST_USER} IDENTIFIED WITH plaintext_password BY 'pass'"
${DATASTORE_CLIENT} -q "GRANT SELECT ON INFORMATION_SCHEMA.* TO ${TEST_USER}"
${DATASTORE_CLIENT} -q "GRANT SELECT ON system.* TO ${TEST_USER}"
${DATASTORE_CLIENT} -q "GRANT CREATE TEMPORARY TABLE, MYSQL, REMOTE ON *.* TO ${TEST_USER}"

${DATASTORE_CLIENT} -q "SYSTEM FLUSH LOGS session_log"
${DATASTORE_CLIENT} -q "DELETE FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}'"

${DATASTORE_CURL} -sS -X POST "${DATASTORE_URL}&user=${TEST_USER}&password=pass" \
   -d "SELECT * FROM remote('127.0.0.1:${DATASTORE_PORT_TCP}', 'system', 'one', '${TEST_USER}', 'pass')"

${DATASTORE_CURL} -sS -X POST "${DATASTORE_URL}&user=${TEST_USER}&password=pass" \
    -d "SELECT * FROM mysql('127.0.0.1:9004', 'system', 'one', '${TEST_USER}', 'pass')"

${DATASTORE_CLIENT} -q "SELECT * FROM remote('127.0.0.1:${DATASTORE_PORT_TCP}', 'system', 'one', '${TEST_USER}', 'pass')" -u "${TEST_USER}" --password "pass"
${DATASTORE_CLIENT} -q "SELECT * FROM mysql('127.0.0.1:9004', 'system', 'one', '${TEST_USER}', 'pass')" -u "${TEST_USER}" --password "pass"

${DATASTORE_CLIENT} -q "SYSTEM FLUSH LOGS session_log"

echo "client_port 0 connections:"
${DATASTORE_CLIENT} -q "SELECT count(*) FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' and client_port = 0"

echo "client_address '::' connections:"
${DATASTORE_CLIENT} -q "SELECT count(*) FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' and client_address = toIPv6('::')"

echo "login failures:"
${DATASTORE_CLIENT} -q "SELECT count(*) FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' and type = 'LoginFailure'"

# remote(...) function sometimes reuses old cached sessions for query execution.
# This makes LoginSuccess/Logout entries count unstable, but success and logouts must always match.

for interface in 'TCP' 'HTTP' 'MySQL'
do
    LOGIN_COUNT=`${DATASTORE_CLIENT} -q "SELECT count(*) FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' AND type = 'LoginSuccess' AND interface = '${interface}'"`
    CORRESPONDING_LOGOUT_RECORDS_COUNT=`${DATASTORE_CLIENT} -q "SELECT COUNT(*) FROM (SELECT ${SESSION_LOG_MATCHING_FIELDS} FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' AND type = 'LoginSuccess' AND interface = '${interface}' INTERSECT SELECT ${SESSION_LOG_MATCHING_FIELDS} FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' AND type = 'Logout' AND interface = '${interface}')"`
    # The client can exit sooner than the server records its disconnection and closes the session.
    # When the client disconnects, two processes happen at the same time and are in the race condition:
    # - the client application exits and returns control to the shell;
    # - the server closes the session and records the logout event to the session log.
    # We cannot expect that after the control is returned to the shell, the server records the logout event.
    while [ "$LOGIN_COUNT" != "$CORRESPONDING_LOGOUT_RECORDS_COUNT" ]
    do
        sleep 0.1
        CORRESPONDING_LOGOUT_RECORDS_COUNT=`${DATASTORE_CLIENT} -q "SELECT COUNT(*) FROM (SELECT ${SESSION_LOG_MATCHING_FIELDS} FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' AND type = 'LoginSuccess' AND interface = '${interface}' INTERSECT SELECT ${SESSION_LOG_MATCHING_FIELDS} FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' AND type = 'Logout' AND interface = '${interface}')"`
    done

    if [ "$LOGIN_COUNT" == "$CORRESPONDING_LOGOUT_RECORDS_COUNT" ]; then
        echo "${interface} Login and logout count is equal"
    else
        TOTAL_LOGOUT_COUNT=`${DATASTORE_CLIENT} -q "SELECT count(*) FROM system.session_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND user = '${TEST_USER}' AND type = 'Logout' AND interface = '${interface}'"`
        echo "${interface} Login count ${LOGIN_COUNT} != corresponding logout count ${CORRESPONDING_LOGOUT_RECORDS_COUNT}. TOTAL_LOGOUT_COUNT ${TOTAL_LOGOUT_COUNT}"
    fi
done

${DATASTORE_CLIENT} -q "DROP USER ${TEST_USER}"
