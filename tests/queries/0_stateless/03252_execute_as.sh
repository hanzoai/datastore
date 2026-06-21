#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

TEST_DATABASE=${DATASTORE_DATABASE}

TEST_USER="testuser_${DATASTORE_DATABASE}"
SERVICE_USER="serviceuser_${DATASTORE_DATABASE}"
APP_USER1="appuser1_${DATASTORE_DATABASE}"
APP_USER2="appuser2_${DATASTORE_DATABASE}"
OTHER_USER="otheruser_${DATASTORE_DATABASE}"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${TEST_USER}, ${SERVICE_USER}, ${APP_USER1}, ${APP_USER2}, ${OTHER_USER}"
$DATASTORE_CLIENT --query "CREATE USER ${TEST_USER}, ${SERVICE_USER}, ${APP_USER1}, ${APP_USER2}, ${OTHER_USER}"

$DATASTORE_CLIENT --query "GRANT ALL ON ${TEST_DATABASE}.* TO ${SERVICE_USER} WITH GRANT OPTION"
$DATASTORE_CLIENT --query "GRANT IMPERSONATE ON ${APP_USER1} TO ${TEST_USER}"
$DATASTORE_CLIENT --query "GRANT IMPERSONATE ON ${APP_USER2} TO ${TEST_USER}"

$DATASTORE_CLIENT --query "CREATE TABLE test1 (id UInt64) Engine=Memory()"
$DATASTORE_CLIENT --query "GRANT SELECT ON test1 TO ${APP_USER1}"
$DATASTORE_CLIENT --query "SELECT currentUser(), authenticatedUser()"

echo -e "\n--- EXECUTE AS app_user1 ---"
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER1}; SELECT currentUser(), authenticatedUser(); SELECT count() FROM test1;"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER1} SELECT currentUser(), authenticatedUser(); SELECT currentUser(), authenticatedUser();"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER1} SELECT count() FROM test1; SELECT currentUser(), authenticatedUser();"

echo -e "\n--- EXECUTE AS app_user2 ---"
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER2}; SELECT currentUser(), authenticatedUser();"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER2}; SELECT currentUser(), authenticatedUser(); SELECT count() FROM test1;" 2>&1 | grep -q -F "ACCESS_DENIED" && echo "OK" || echo "FAIL"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER2} SELECT currentUser(), authenticatedUser(); SELECT currentUser(), authenticatedUser();"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER2} SELECT count() FROM test1" 2>&1 | grep -q -F "ACCESS_DENIED" && echo "OK" || echo "FAIL"

echo -e "\n--- EXECUTE AS other_user ---"
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${OTHER_USER}" 2>&1 | grep -q -F "ACCESS_DENIED" && echo "OK" || echo "FAIL"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${OTHER_USER} SELECT 1" 2>&1 | grep -q -F "ACCESS_DENIED" && echo "OK" || echo "FAIL"

echo -e "\n--- Multiple EXECUTE AS ---"
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER1} SELECT currentUser(), authenticatedUser(); EXECUTE AS ${APP_USER2} SELECT currentUser(), authenticatedUser(); EXECUTE AS ${APP_USER1} SELECT currentUser(), authenticatedUser(); SELECT currentUser(), authenticatedUser();"
echo
$DATASTORE_CLIENT --user ${TEST_USER} --query "EXECUTE AS ${APP_USER1}; SELECT currentUser(), authenticatedUser(); EXECUTE AS ${APP_USER2};" 2>&1 | grep -q -F "ACCESS_DENIED" && echo "OK" || echo "FAIL"

$DATASTORE_CLIENT --query "DROP USER ${TEST_USER}, ${SERVICE_USER}, ${APP_USER1}, ${APP_USER2}, ${OTHER_USER}"
