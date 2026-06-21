#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

db=${DATASTORE_DATABASE}
user=user_${DATASTORE_TEST_UNIQUE_NAME}
role=role_${DATASTORE_TEST_UNIQUE_NAME}

${DATASTORE_CLIENT} --query "DROP ROLE IF EXISTS $role; DROP USER IF EXISTS $user; DROP TABLE IF EXISTS ${db}.tb;"

${DATASTORE_CLIENT} --query "CREATE USER $user; GRANT SELECT ON ${db}.tb TO $user;"

# Has been granted but not table not exists 
# expected to 1
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "CHECK GRANT SELECT ON ${db}.tb"

${DATASTORE_CLIENT} --query "CREATE TABLE ${db}.tb (\`content\` UInt64) ENGINE = MergeTree ORDER BY content; INSERT INTO ${db}.tb VALUES (1);"
# Has been granted and table exists
# expected to 1
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "CHECK GRANT SELECT ON ${db}.tb"

${DATASTORE_CLIENT} --query "REVOKE SELECT ON ${db}.tb FROM $user;"
# Has not been granted but table exists
# expected to 0
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "CHECK GRANT SELECT ON ${db}.tb"

# Role
# expected to 1
${DATASTORE_CLIENT} --query "CREATE ROLE $role; GRANT SELECT ON ${db}.tb TO $role; GRANT $role TO $user"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "SET ROLE $role"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "CHECK GRANT SELECT ON ${db}.tb"

# wildcard
${DATASTORE_CLIENT} --query "GRANT SELECT ON ${db}.tbb* TO $user;"
# expected to 1
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "CHECK GRANT SELECT ON ${db}.tbb1"
# expected to 1
${DATASTORE_CURL} -sS "${DATASTORE_URL}&user=$user" --data-binary "CHECK GRANT SELECT ON ${db}.tbb2*"

${DATASTORE_CLIENT} --query "DROP ROLE $role; DROP USER $user; DROP TABLE $db.tb;"
