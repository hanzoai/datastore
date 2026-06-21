#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

databasename="test_database_${DATASTORE_TEST_UNIQUE_NAME}"
username="test_user_${DATASTORE_TEST_UNIQUE_NAME}"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS ${username}";
${DATASTORE_CLIENT} --query "DROP DATABASE IF EXISTS ${databasename}";

${DATASTORE_CLIENT} --query "CREATE USER ${username};";
${DATASTORE_CLIENT} --query "CREATE DATABASE ${databasename} COMMENT 'test database with comment';";

${DATASTORE_CLIENT} --query "GRANT ALTER MODIFY DATABASE COMMENT ON ${databasename}.* TO ${username};";

${DATASTORE_CLIENT} --query "SHOW GRANTS FOR ${username};";

${DATASTORE_CLIENT} --user="${username}" --query "SHOW GRANTS FOR ${username}" | sed 's/ TO.*//';

${DATASTORE_CLIENT} --user="${username}" --query "SELECT name, comment FROM system.databases WHERE name = '${databasename}';";

${DATASTORE_CLIENT} --user="${username}" --query "ALTER DATABASE ${databasename} MODIFY COMMENT 'new comment on database';"

${DATASTORE_CLIENT} --user="${username}" --query "SELECT name, comment FROM system.databases WHERE name = '${databasename}';";

${DATASTORE_CLIENT} --query "REVOKE ALTER MODIFY DATABASE COMMENT ON ${databasename}.* FROM ${username};";

${DATASTORE_CLIENT} --user="${username}" --query "SHOW GRANTS FOR ${username};";

${DATASTORE_CLIENT} --user="${username}" --query "ALTER DATABASE ${databasename} MODIFY COMMENT 'test alter comment after revoking;' \
    -- { serverError ACCESS_DENIED } ";

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS ${username}";

${DATASTORE_CLIENT} --query "DROP DATABASE IF EXISTS ${databasename}";