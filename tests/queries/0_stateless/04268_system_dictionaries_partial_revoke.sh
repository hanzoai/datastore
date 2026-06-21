#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# Test that system.dictionaries shows dictionaries when SHOW DICTIONARIES
# has a partial revoke on an unrelated table.

USER="test_user_04268_${DATASTORE_DATABASE}"
ROLE="test_role_04268_${DATASTORE_DATABASE}"
DICT="${DATASTORE_DATABASE}.test_dict_04268"

${DATASTORE_CLIENT} -q "DROP DICTIONARY IF EXISTS ${DICT}"
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${ROLE}"

${DATASTORE_CLIENT} -q "
    CREATE DICTIONARY ${DICT} (id UInt64, value String)
    PRIMARY KEY id
    SOURCE(DATASTORE(TABLE 'numbers' DB 'system'))
    LIFETIME(MIN 0 MAX 300)
    LAYOUT(FLAT())
"

# Create role with SHOW DICTIONARIES and a partial revoke on an unrelated table
${DATASTORE_CLIENT} -q "CREATE ROLE ${ROLE}"
${DATASTORE_CLIENT} -q "GRANT SHOW DICTIONARIES, SELECT ON *.* TO ${ROLE}"
${DATASTORE_CLIENT} -q "REVOKE SHOW DICTIONARIES, SELECT ON system.non_existing_table FROM ${ROLE}"

${DATASTORE_CLIENT} -q "CREATE USER ${USER} IDENTIFIED WITH no_password"
${DATASTORE_CLIENT} -q "GRANT ${ROLE} TO ${USER}"

# The dictionary should be visible despite the partial revoke
${DATASTORE_CLIENT} --user "${USER}" -q "SELECT name FROM system.dictionaries WHERE database = '${DATASTORE_DATABASE}' AND name = 'test_dict_04268'"

# The dictionary should also appear in system.completions
${DATASTORE_CLIENT} --user "${USER}" -q "SELECT count() > 0 FROM system.completions WHERE word = 'test_dict_04268'"

# Cleanup
${DATASTORE_CLIENT} -q "DROP DICTIONARY IF EXISTS ${DICT}"
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${ROLE}"
