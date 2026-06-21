#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test"
${DATASTORE_CLIENT} --query "CREATE TABLE test (s String) ENGINE = Memory"

# Calling an unknown function should not lead to creation of a 'user_defined' directory in the current directory
rm -rf user_defined
${DATASTORE_CLIENT} --query "INSERT INTO test VALUES (xyz('abc'))" 2>&1 | grep -q -F 'UNKNOWN_FUNCTION' && echo 1 || echo 0
ls -ld user_defined 2> /dev/null

${DATASTORE_CLIENT} --query "DROP TABLE test"
