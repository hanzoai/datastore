#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user_name="user_03822_${DATASTORE_DATABASE}"
role_name="role_03822_${DATASTORE_DATABASE}"

$DATASTORE_CLIENT -q "DROP USER IF EXISTS ${user_name}"
$DATASTORE_CLIENT -q "DROP ROLE IF EXISTS ${role_name}"

$DATASTORE_CLIENT -q "CREATE USER ${user_name}"
$DATASTORE_CLIENT -q "CREATE ROLE ${role_name}"

$DATASTORE_CLIENT -q "GRANT ${role_name} TO ${user_name}"
$DATASTORE_CLIENT -q "SET DEFAULT ROLE ${role_name} TO ${user_name}"
$DATASTORE_CLIENT -q "SHOW CREATE USER ${user_name}"
$DATASTORE_CLIENT --user ${user_name} -q "SHOW CURRENT ROLES"

echo "After revoke:"
$DATASTORE_CLIENT -q "REVOKE ${role_name} FROM ${user_name}"
$DATASTORE_CLIENT -q "SHOW CREATE USER ${user_name}"
$DATASTORE_CLIENT --user ${user_name} -q "SHOW CURRENT ROLES"

$DATASTORE_CLIENT -q "DROP USER ${user_name}"
$DATASTORE_CLIENT -q "DROP ROLE ${role_name}"
