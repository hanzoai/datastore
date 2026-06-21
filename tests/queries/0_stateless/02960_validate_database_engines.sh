#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

db_name="$DATASTORE_DATABASE"_test2960_valid_database_engine
db_args_name="$DATASTORE_DATABASE"_test2960_database_engine_args_not_allowed
db_invalid_name="$DATASTORE_DATABASE"_test2960_invalid_database_engine

$DATASTORE_CLIENT -q "DROP DATABASE IF EXISTS $db_name"

# create database with valid engine. Should succeed.
$DATASTORE_CLIENT -q "CREATE DATABASE $db_name ENGINE = Atomic"

# create database with valid engine but arguments are not allowed. Should fail.
$DATASTORE_CLIENT -q "CREATE DATABASE $db_args_name ENGINE = Atomic('foo', 'bar')" 2>&1 | grep -q "BAD_ARGUMENTS" || echo "Missing BAD_ARGUMENTS error"

# create database with an invalid engine. Should fail.
$DATASTORE_CLIENT -q "CREATE DATABASE $db_invalid_name ENGINE = Foo" 2>&1 | grep -q "UNKNOWN_DATABASE_ENGINE" || echo "Missing UNKNOWN_DATABASE_ENGINE error"

$DATASTORE_CLIENT -q "DROP DATABASE IF EXISTS $db_name"
