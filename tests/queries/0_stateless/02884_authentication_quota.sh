#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

QUOTA="2884_quota_${DATASTORE_DATABASE}"
USER="2884_user_${DATASTORE_DATABASE}"
ROLE="2884_role_${DATASTORE_DATABASE}"


function login_test()
{
    echo "> Try to login to the user account with correct password"
    ${DATASTORE_CLIENT} --user ${USER} --password "pass" --query "select 1 format Null"

    echo "> Login to the user account using the wrong password."
    ${DATASTORE_CLIENT} --user ${USER} --password "wrong_pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'password is incorrect'

    echo "> Quota is exceeded 1 >= 1. Login with correct password should fail."
    ${DATASTORE_CLIENT} --user ${USER} --password "pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'QUOTA_EXCEEDED'

    echo "> Check the failed_sequential_authentications, max_failed_sequential_authentications fields."
    ${DATASTORE_CLIENT} -q "SELECT failed_sequential_authentications, max_failed_sequential_authentications FROM system.quotas_usage WHERE quota_name = '${QUOTA}'"

    echo "> Alter the quota with MAX FAILED SEQUENTIAL AUTHENTICATIONS = 4"
    ${DATASTORE_CLIENT} -q "ALTER QUOTA ${QUOTA} FOR INTERVAL 100 YEAR MAX FAILED SEQUENTIAL AUTHENTICATIONS = 4 TO ${USER}"

    echo "> Try to login to the user account with correct password"
    ${DATASTORE_CLIENT} --user ${USER} --password "pass" --query "select 1 format Null"

    echo "> Successful login should reset failed authentications counter. Check the failed_sequential_authentications, max_failed_sequential_authentications fields."
    ${DATASTORE_CLIENT} -q "SELECT failed_sequential_authentications, max_failed_sequential_authentications FROM system.quotas_usage WHERE quota_name = '${QUOTA}'"

    echo "> Login to the user account using the wrong password before exceeding the quota."
    ${DATASTORE_CLIENT} --user ${USER} --password "wrong_pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'password is incorrect'
    ${DATASTORE_CLIENT} --user ${USER} --password "wrong_pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'password is incorrect'
    ${DATASTORE_CLIENT} --user ${USER} --password "wrong_pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'password is incorrect'
    ${DATASTORE_CLIENT} --user ${USER} --password "wrong_pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'password is incorrect'
    ${DATASTORE_CLIENT} --user ${USER} --password "wrong_pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'QUOTA_EXCEEDED'

    echo "> Also try to login with correct password. Quota should stay exceeded."
    ${DATASTORE_CLIENT} --user ${USER} --password "pass" --query "select 1 format Null" 2>&1 | grep -m1 -o 'QUOTA_EXCEEDED'

    echo "> Check the failed_sequential_authentications, max_failed_sequential_authentications fields."
    ${DATASTORE_CLIENT} -q "SELECT failed_sequential_authentications, max_failed_sequential_authentications FROM system.quotas_usage WHERE quota_name = '${QUOTA}'"

    echo "> Reset the quota by increasing MAX FAILED SEQUENTIAL AUTHENTICATIONS and successful login"
    echo "> and check failed_sequential_authentications, max_failed_sequential_authentications."
    ${DATASTORE_CLIENT} -q "ALTER QUOTA ${QUOTA} FOR INTERVAL 100 YEAR MAX FAILED SEQUENTIAL AUTHENTICATIONS = 7 TO ${USER}"
    ${DATASTORE_CLIENT} --user ${USER} --password "pass" --query "select 1 format Null"
    ${DATASTORE_CLIENT} -q "SELECT failed_sequential_authentications, max_failed_sequential_authentications FROM system.quotas_usage WHERE quota_name = '${QUOTA}'"
}

echo "> Drop the user, quota, and role if those were created."
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "DROP QUOTA IF EXISTS ${QUOTA}"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${ROLE}"

echo "> Create the user with quota with the maximum single authentication attempt."
${DATASTORE_CLIENT} -q "CREATE USER ${USER} IDENTIFIED WITH plaintext_password BY 'pass'"
${DATASTORE_CLIENT} -q "CREATE QUOTA ${QUOTA} FOR INTERVAL 100 YEAR MAX FAILED SEQUENTIAL AUTHENTICATIONS = 1 TO ${USER}"

echo "> Check if the quota has been created."
${DATASTORE_CLIENT} -q "SELECT COUNT(*) FROM system.quotas WHERE name = '${QUOTA}'"

login_test

echo " ---------------------------------------------------------------------------"
echo "> Create the role with quota with the maximum single authentication attempt."
${DATASTORE_CLIENT} -q "CREATE ROLE ${ROLE}"
${DATASTORE_CLIENT} -q "GRANT ALL ON *.* TO ${ROLE}"
${DATASTORE_CLIENT} -q "GRANT ${ROLE} to ${USER}"
${DATASTORE_CLIENT} -q "ALTER QUOTA ${QUOTA} FOR INTERVAL 100 YEAR MAX FAILED SEQUENTIAL AUTHENTICATIONS = 1 TO ${ROLE}"

login_test

${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "DROP QUOTA IF EXISTS ${QUOTA}"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${ROLE}"
