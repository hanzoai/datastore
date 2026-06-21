#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

SESSION_ID="02947_session_${DATASTORE_DATABASE}"
TEST_DB="non_post_request_test_${DATASTORE_DATABASE}"

# This should fail
${DATASTORE_CURL} -X GET -sS "${DATASTORE_URL}&session_id=${SESSION_ID}&query=CREATE+DATABASE+${TEST_DB}" | grep -o "Cannot execute query in readonly mode"

# This should fail
${DATASTORE_CURL} --head -sS "${DATASTORE_URL}&session_id=${SESSION_ID}&query=CREATE+DATABASE+${TEST_DB}" | grep -o "Internal Server Error"

# This should pass - but will throw error "non_post_request_test already exists" if the database was created by any of the above requests.
${DATASTORE_CURL} -X POST -sS "${DATASTORE_URL}&session_id=${SESSION_ID}" -d "CREATE DATABASE ${TEST_DB}"
${DATASTORE_CURL} -X POST -sS "${DATASTORE_URL}&session_id=${SESSION_ID}" -d "DROP DATABASE ${TEST_DB}"
