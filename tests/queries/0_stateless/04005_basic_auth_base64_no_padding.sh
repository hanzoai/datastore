#!/usr/bin/env bash
# Tags: no-fasttest

# Test that HTTP basic auth accepts base64-encoded credentials
# without padding ('=' characters). Some HTTP clients omit padding
# in the Authorization header.

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# "default:" base64-padded is "ZGVmYXVsdDo=", unpadded is "ZGVmYXVsdDo"

# Padded — should work
${DATASTORE_CURL} -sS -H "Authorization: Basic ZGVmYXVsdDo=" "${DATASTORE_URL}&query=SELECT+1"

# Unpadded — should also work (this is the bug fix)
${DATASTORE_CURL} -sS -H "Authorization: Basic ZGVmYXVsdDo" "${DATASTORE_URL}&query=SELECT+1"

# Test with 2 padding chars: use a unique user name per test run to avoid
# collisions during parallel flaky checks.
USER_NAME="test_b64_${DATASTORE_DATABASE}"
PASSWORD="p"

${DATASTORE_CLIENT} -q "CREATE USER IF NOT EXISTS ${USER_NAME} IDENTIFIED BY '${PASSWORD}'"
${DATASTORE_CLIENT} -q "GRANT SELECT ON system.one TO ${USER_NAME}"

# Compute base64 at runtime (padded)
B64_PADDED=$(echo -n "${USER_NAME}:${PASSWORD}" | base64)
# Strip padding
B64_UNPADDED=$(echo -n "${B64_PADDED}" | tr -d '=')

# Padded
${DATASTORE_CURL} -sS -H "Authorization: Basic ${B64_PADDED}" "${DATASTORE_URL}&query=SELECT+1"

# Unpadded — this is the bug fix
${DATASTORE_CURL} -sS -H "Authorization: Basic ${B64_UNPADDED}" "${DATASTORE_URL}&query=SELECT+1"

${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER_NAME}"
