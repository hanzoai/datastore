#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# datastore-local and datastore-client behave the same
$DATASTORE_CLIENT -q "select 1; select 2;"
$DATASTORE_LOCAL -q "select 1; select 2;"

# -n is a no-op
$DATASTORE_CLIENT -q "select 1; select 2;"
$DATASTORE_LOCAL -q "select 1; select 2;"

exit 0
