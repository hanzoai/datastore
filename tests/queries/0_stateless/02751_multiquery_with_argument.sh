#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL "SELECT 100"
$DATASTORE_LOCAL "SELECT 101;"
$DATASTORE_LOCAL "SELECT 102;SELECT 103;"

# Invalid SQL.
$DATASTORE_LOCAL --implicit-select 0 "SELECT 200; S" 2>&1 | grep -o 'Syntax error'
$DATASTORE_LOCAL "; SELECT 201;" 2>&1 | grep -o 'Empty query'
$DATASTORE_LOCAL "; S; SELECT 202" 2>&1 | grep -o 'Empty query'

# Error expectation cases.
# -n <SQL> is also interpreted as a query
$DATASTORE_LOCAL -n "SELECT 301"
$DATASTORE_LOCAL -n "SELECT 302;"
$DATASTORE_LOCAL -n "SELECT 304;SELECT 305;"
# --multiquery and -n are obsolete by now and no-ops.
# The only exception is a single --multiquery "<some_query>"
$DATASTORE_LOCAL --multiquery --multiquery 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL -n --multiquery 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --multiquery -n 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --multiquery --multiquery "SELECT 306; SELECT 307;" 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL -n --multiquery "SELECT 307; SELECT 308;" 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --multiquery "SELECT 309; SELECT 310;" --multiquery 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --multiquery "SELECT 311;" --multiquery "SELECT 312;" 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --multiquery "SELECT 313;" -n "SELECT 314;" 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL -n "SELECT 320" --query "SELECT 317;"
# --query should be followed by SQL
$DATASTORE_LOCAL --query -n "SELECT 400;" 2>&1 | grep -o 'Bad arguments'
$DATASTORE_LOCAL --query -n --multiquery "SELECT 401;" 2>&1 | grep -o 'Bad arguments'
