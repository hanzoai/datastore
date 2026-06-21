#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL --path "${DATASTORE_TMP}" "CREATE FUNCTION f AS x -> x + 1; SELECT f(1);"
$DATASTORE_LOCAL --path "${DATASTORE_TMP}" "SELECT f(2); DROP FUNCTION f;"
