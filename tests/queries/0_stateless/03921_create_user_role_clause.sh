#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user1="user1_${DATASTORE_DATABASE}"
role1="role1_${DATASTORE_DATABASE}"
role2="role2_${DATASTORE_DATABASE}"
role3="role3_${DATASTORE_DATABASE}"

$DATASTORE_CLIENT --query "
    DROP USER IF EXISTS $user1;
    DROP ROLE IF EXISTS $role1, $role2, $role3;
    "

$DATASTORE_CLIENT --query "
    CREATE ROLE $role1;
    CREATE ROLE $role2;
    CREATE ROLE $role3;
"

echo A
$DATASTORE_CLIENT --query "CREATE USER $user1 ROLE $role1, $role2"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "GRANT $role3 TO $user1"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "DROP USER $user1"
echo

echo B
$DATASTORE_CLIENT --query "CREATE USER $user1 ROLE $role1, $role2 DEFAULT ROLE $role2"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "GRANT $role3 TO $user1"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "DROP USER $user1"
echo

echo C
$DATASTORE_CLIENT --query "CREATE USER $user1 ROLE $role1, $role2 DEFAULT ROLE ALL EXCEPT $role2"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "GRANT $role3 TO $user1"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "SET DEFAULT ROLE $role3 TO $user1"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "ALTER USER $user1 DEFAULT ROLE ALL"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "ALTER USER $user1 ROLE $role1" 2>&1 | grep -o 'Syntax error' | uniq
$DATASTORE_CLIENT --query "DROP USER $user1"
echo

echo D
$DATASTORE_CLIENT --query "CREATE USER $user1 DEFAULT ROLE $role1, $role2"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "GRANT $role3 TO $user1"
$DATASTORE_CLIENT --query "SHOW CREATE USER $user1"
$DATASTORE_CLIENT --query "SELECT granted_role_name, granted_role_is_default FROM system.role_grants WHERE user_name='$user1' ORDER BY granted_role_name"
$DATASTORE_CLIENT --query "DROP USER $user1"
echo

echo E
$DATASTORE_CLIENT --query "CREATE USER $user1 ROLE $role1, $role2 DEFAULT ROLE $role3" 2>&1 | grep -o 'SET_NON_GRANTED_ROLE' | uniq
$DATASTORE_CLIENT --query "CREATE USER $user1 ROLE ALL" 2>&1 | grep -o 'Syntax error' | uniq

$DATASTORE_CLIENT --query "DROP ROLE IF EXISTS $role1, $role2, $role3"
