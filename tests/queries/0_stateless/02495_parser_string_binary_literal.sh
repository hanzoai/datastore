#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT --query="SELECT b '0';" 2>&1 | grep -o 'Syntax error'
$DATASTORE_CLIENT --query="SELECT x 'a'" 2>&1 | grep -o 'Syntax error'

$DATASTORE_CLIENT --query="SELECT b'3';" 2>&1 | grep -o 'Syntax error'
$DATASTORE_CLIENT --query="SELECT x'k'" 2>&1 | grep -o 'Syntax error'

$DATASTORE_CLIENT --query="SELECT b'1" 2>&1 | grep -o 'Syntax error'
$DATASTORE_CLIENT --query="SELECT x'a" 2>&1 | grep -o 'Syntax error'
