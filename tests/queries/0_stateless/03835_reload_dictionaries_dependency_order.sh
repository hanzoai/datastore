#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest

# Verify that SYSTEM RELOAD DICTIONARIES reloads dictionaries in topological order,
# so that dictionaries sourcing from other dictionaries see fresh data.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1}"
$DATASTORE_CLIENT -q "CREATE DATABASE ${DATASTORE_DATABASE_1}"

$DATASTORE_CLIENT -q "CREATE TABLE ${DATASTORE_DATABASE_1}.source (id UInt64, value String) ENGINE = MergeTree ORDER BY id"
$DATASTORE_CLIENT -q "INSERT INTO ${DATASTORE_DATABASE_1}.source VALUES (1, 'a'), (2, 'b'), (3, 'c')"

# Chain: source -> d1 -> d2 -> d3
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY ${DATASTORE_DATABASE_1}.d1 (id UInt64, value String)
    PRIMARY KEY id
    SOURCE(DATASTORE(TABLE 'source' DB '${DATASTORE_DATABASE_1}'))
    LIFETIME(0)
    LAYOUT(FLAT())
"

$DATASTORE_CLIENT -q "
    CREATE DICTIONARY ${DATASTORE_DATABASE_1}.d2 (id UInt64, value String)
    PRIMARY KEY id
    SOURCE(DATASTORE(TABLE 'd1' DB '${DATASTORE_DATABASE_1}'))
    LIFETIME(0)
    LAYOUT(FLAT())
"

$DATASTORE_CLIENT -q "
    CREATE DICTIONARY ${DATASTORE_DATABASE_1}.d3 (id UInt64, value String)
    PRIMARY KEY id
    SOURCE(DATASTORE(TABLE 'd2' DB '${DATASTORE_DATABASE_1}'))
    LIFETIME(0)
    LAYOUT(FLAT())
"

# Trigger initial load of the entire chain
$DATASTORE_CLIENT -q "SELECT count() FROM ${DATASTORE_DATABASE_1}.d3"

# Insert more data into the source table
$DATASTORE_CLIENT -q "INSERT INTO ${DATASTORE_DATABASE_1}.source VALUES (4, 'd'), (5, 'e')"

# Reload all dictionaries; with topological ordering d1 reloads before d2 before d3
$DATASTORE_CLIENT -q "SYSTEM RELOAD DICTIONARIES"

# All dictionaries should see the updated 5 rows
$DATASTORE_CLIENT -q "SELECT count() FROM ${DATASTORE_DATABASE_1}.d1"
$DATASTORE_CLIENT -q "SELECT count() FROM ${DATASTORE_DATABASE_1}.d2"
$DATASTORE_CLIENT -q "SELECT count() FROM ${DATASTORE_DATABASE_1}.d3"

$DATASTORE_CLIENT -q "DROP DATABASE ${DATASTORE_DATABASE_1}"
