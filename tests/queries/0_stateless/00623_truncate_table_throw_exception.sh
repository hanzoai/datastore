#!/usr/bin/env bash
# Tags: no-parallel

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1};"

${DATASTORE_CLIENT} --query "CREATE DATABASE ${DATASTORE_DATABASE_1};"

${DATASTORE_CLIENT} --query "SELECT '========Before Truncate========';"
${DATASTORE_CLIENT} --query "CREATE TABLE ${DATASTORE_DATABASE_1}.test_view_depend (s String) ENGINE = Log;"
${DATASTORE_CLIENT} --query "CREATE VIEW ${DATASTORE_DATABASE_1}.test_view AS SELECT * FROM ${DATASTORE_DATABASE_1}.test_view_depend;"

${DATASTORE_CLIENT} --query "INSERT INTO ${DATASTORE_DATABASE_1}.test_view_depend VALUES('test_string');"
${DATASTORE_CLIENT} --query "SELECT * FROM ${DATASTORE_DATABASE_1}.test_view;"

${DATASTORE_CLIENT} --query "SELECT '========Execute Truncate========';"
echo "$(${DATASTORE_CLIENT} --query "TRUNCATE TABLE ${DATASTORE_DATABASE_1}.test_view;" --server_logs_file=/dev/null 2>&1 | grep -c "Code: 48.*Truncate is not supported by storage View")"

${DATASTORE_CLIENT} --query "SELECT '========After Truncate========';"
${DATASTORE_CLIENT} --query "SELECT * FROM ${DATASTORE_DATABASE_1}.test_view;"

${DATASTORE_CLIENT} --query "DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1};"
