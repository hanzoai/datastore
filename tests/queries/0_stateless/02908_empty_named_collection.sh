#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

collection_name="$DATASTORE_DATABASE"_foobar03

$DATASTORE_CLIENT -q "CREATE NAMED COLLECTION $collection_name AS a = 1"

$DATASTORE_CLIENT -q "ALTER NAMED COLLECTION $collection_name DELETE b" 2>&1 | grep -q "BAD_ARGUMENTS" || echo "Missing BAD_ARGUMENTS error"

$DATASTORE_CLIENT -q "DROP NAMED COLLECTION $collection_name"
