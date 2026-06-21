#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest
# Tag no-fasttest: Checks system.errors

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# local
prev="$(${DATASTORE_CLIENT} -q "SELECT value FROM system.errors WHERE name = 'FUNCTION_THROW_IF_VALUE_IS_NON_ZERO' AND NOT remote")"
$DATASTORE_CLIENT -q 'SELECT throwIf(1)' >& /dev/null
cur="$(${DATASTORE_CLIENT} -q "SELECT value FROM system.errors WHERE name = 'FUNCTION_THROW_IF_VALUE_IS_NON_ZERO' AND NOT remote")"
echo local=$((cur - prev))

# remote
prev="$(${DATASTORE_CLIENT} -q "SELECT value FROM system.errors WHERE name = 'FUNCTION_THROW_IF_VALUE_IS_NON_ZERO' AND remote")"
${DATASTORE_CLIENT} -q "SELECT * FROM remote('127.2', system.one) where throwIf(not dummy)" >& /dev/null
cur="$(${DATASTORE_CLIENT} -q "SELECT value FROM system.errors WHERE name = 'FUNCTION_THROW_IF_VALUE_IS_NON_ZERO' AND remote")"
echo remote=$((cur - prev))
