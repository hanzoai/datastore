#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "SELECT 1; SELECT 2; SELECT CAST(); SELECT ';'; SELECT 3;SELECT CAST();SELECT 4;" | $DATASTORE_CLIENT --ignore-error 2>/dev/null
echo "SELECT CAST();" | $DATASTORE_CLIENT --ignore-error 2>/dev/null
echo "SELECT 5;" | $DATASTORE_CLIENT --ignore-error

#$DATASTORE_CLIENT -q "SELECT 'Still alive'"
