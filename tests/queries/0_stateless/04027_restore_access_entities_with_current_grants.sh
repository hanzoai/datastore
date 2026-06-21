#!/usr/bin/env bash
# Tags: no-parallel

# Disabled parallel since RESTORE can only restore either all users or no users
# (it can't restore only users added by the current test run),
# so a RESTORE from a parallel test run could recreate our users before we expect that.

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user_a="user_a_${DATASTORE_TEST_UNIQUE_NAME}"
role_b="role_b_${DATASTORE_TEST_UNIQUE_NAME}"
restoring_user="restoring_user_${DATASTORE_TEST_UNIQUE_NAME}"
no_grant_user="no_grant_user_${DATASTORE_TEST_UNIQUE_NAME}"

${DATASTORE_CLIENT} -m --query "
DROP USER IF EXISTS ${user_a};
DROP ROLE IF EXISTS ${role_b};
DROP USER IF EXISTS ${restoring_user};
DROP USER IF EXISTS ${no_grant_user};
"

# Create a user and role with broad permissions.
${DATASTORE_CLIENT} -m --query "
CREATE ROLE ${role_b};
GRANT SELECT, INSERT, ALTER ON *.* TO ${role_b};
CREATE USER ${user_a} DEFAULT ROLE ${role_b};
GRANT SELECT, INSERT, ALTER, CREATE ON *.* TO ${user_a};
"

backup_name="Disk('backups', '${DATASTORE_TEST_UNIQUE_NAME}')"

${DATASTORE_CLIENT} --query "BACKUP TABLE system.users, TABLE system.roles TO ${backup_name} FORMAT Null"

# Create a restoring user that has fewer permissions than user_a and role_b.
# This user can create users/roles, but only has GRANT OPTION on SELECT (not INSERT, ALTER, CREATE).
${DATASTORE_CLIENT} -m --query "
CREATE USER ${restoring_user};
GRANT CREATE USER, CREATE ROLE ON *.* TO ${restoring_user};
GRANT ROLE ADMIN ON *.* TO ${restoring_user};
GRANT SELECT ON *.* TO ${restoring_user} WITH GRANT OPTION;
"

# Drop the entities we will restore.
${DATASTORE_CLIENT} -m --query "
DROP USER ${user_a};
DROP ROLE ${role_b};
"

# 1) Without the setting, RESTORE should fail because restoring_user can't grant INSERT/ALTER/CREATE.
echo "--- Restore without setting (should fail) ---"
${DATASTORE_CLIENT} --user="${restoring_user}" --query "RESTORE ALL FROM ${backup_name} FORMAT Null" 2>&1 | grep -om1 "ACCESS_DENIED"

# 2) With the setting, RESTORE should succeed, but grants are limited.
echo "--- Restore with restore_access_entities_with_current_grants=true ---"
${DATASTORE_CLIENT} --user="${restoring_user}" --query "RESTORE ALL FROM ${backup_name} SETTINGS restore_access_entities_with_current_grants=true FORMAT Null"

replacements="s/${user_a}/user_a/g; s/${role_b}/role_b/g"

echo "-- user_a grants (should only have SELECT, not INSERT/ALTER/CREATE) --"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR ${user_a}" | sed "${replacements}"

echo "-- role_b grants (should only have SELECT, not INSERT/ALTER) --"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR ${role_b}" | sed "${replacements}"

# 3) Test the extreme case: restoring user has NO grant option at all.
echo "--- Extreme case: restoring user has no GRANT OPTION ---"
${DATASTORE_CLIENT} -m --query "
DROP USER ${user_a};
DROP ROLE ${role_b};
"

${DATASTORE_CLIENT} -m --query "
CREATE USER ${no_grant_user};
GRANT CREATE USER, CREATE ROLE ON *.* TO ${no_grant_user};
GRANT ROLE ADMIN ON *.* TO ${no_grant_user};
"

${DATASTORE_CLIENT} --user="${no_grant_user}" --query "RESTORE ALL FROM ${backup_name} SETTINGS restore_access_entities_with_current_grants=true FORMAT Null"

echo "-- user_a grants (should have no access grants, only role assignment) --"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR ${user_a}" | sed "${replacements}"

echo "-- role_b grants (should be empty) --"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR ${role_b}" | sed "${replacements}"

# Cleanup
${DATASTORE_CLIENT} -m --query "
DROP USER IF EXISTS ${user_a};
DROP ROLE IF EXISTS ${role_b};
DROP USER IF EXISTS ${restoring_user};
DROP USER IF EXISTS ${no_grant_user};
"
