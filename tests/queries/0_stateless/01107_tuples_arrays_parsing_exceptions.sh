#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "SELECT (1, 2 2)" 2>&1 | grep -o "Syntax error"
$DATASTORE_CLIENT -q "SELECT [1, 2 2]" 2>&1 | grep -o "Syntax error"