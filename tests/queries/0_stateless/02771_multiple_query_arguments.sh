#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# datastore-client
$DATASTORE_CLIENT --query "SELECT 101" --query "SELECT 101"
$DATASTORE_CLIENT --query "SELECT 202;" --query "SELECT 202;"
$DATASTORE_CLIENT --query "SELECT 303" --query "SELECT 303; SELECT 303"
$DATASTORE_CLIENT --query "" --query "" 2>&1
$DATASTORE_CLIENT --query "SELECT 303" --query 2>&1 | grep -o 'Bad arguments'
$DATASTORE_CLIENT --query "SELECT 303" --query "SELE" 2>&1 | grep -o 'Syntax error'

# datastore-local
$DATASTORE_LOCAL --query "SELECT 101" --query "SELECT 101"
$DATASTORE_LOCAL --query "SELECT 202;" --query "SELECT 202;"
$DATASTORE_LOCAL --query "SELECT 303" --query "SELECT 303; SELECT 303"
$DATASTORE_LOCAL --query "" --query ""
$DATASTORE_LOCAL --query "SELECT 303" --query 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --implicit-select 0 --query "SELECT 303" --query "SELE" 2>&1 | grep -o 'Syntax error'
