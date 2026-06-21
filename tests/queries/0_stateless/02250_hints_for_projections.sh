#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS t"

$DATASTORE_CLIENT --query="create table t (x Int32, y Int32, projection pToDrop (select x, y order by x)) engine = MergeTree order by y;"

$DATASTORE_CLIENT --query="ALTER TABLE t DROP PROJECTION pToDro" 2>&1 | grep -q "Maybe you meant: \['pToDrop'\]" && echo 'OK' || echo 'FAIL'

$DATASTORE_CLIENT --query="DROP TABLE t"
