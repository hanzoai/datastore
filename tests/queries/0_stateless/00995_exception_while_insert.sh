#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATASTORE_CLIENT_SERVER_LOGS_LEVEL=none
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS check;"

$DATASTORE_CLIENT --query="CREATE TABLE check (x UInt64, y UInt64 DEFAULT throwIf(x = 1500000)) ENGINE = Memory;"

seq 1 1500000 | $DATASTORE_CLIENT --query="INSERT INTO check(x) FORMAT TSV" 2>&1 | grep -q "Value passed to 'throwIf' function is non-zero." && echo 'OK' || echo 'FAIL' ||:

$DATASTORE_CLIENT --query="DROP TABLE check;"
