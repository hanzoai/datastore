#!/usr/bin/env bash
# Tags: no-replicated-database, no-parallel, no-fasttest
# Tag no-replicated-database: grep -c

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "DROP DICTIONARY IF  EXISTS dict1"

# Simple layout, but with non existing key
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    PRIMARY KEY non_existing_column
    LAYOUT(HASHED())
    SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' DB '$DATASTORE_DATABASE'))
    LIFETIME(MIN 1 MAX 10)
" 2>&1 | grep -c "Unknown key attribute 'non_existing_column'"

# Complex layout, with non existing key
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    PRIMARY KEY non_existing_column, key1
    LAYOUT(COMPLEX_KEY_HASHED())
    SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' DB '$DATASTORE_DATABASE'))
    LIFETIME(MIN 1 MAX 10)
" 2>&1 | grep -c "Unknown key attribute 'non_existing_column'"

# No layout
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    PRIMARY KEY key2, key1
    SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' DB '$DATASTORE_DATABASE'))
    LIFETIME(MIN 1 MAX 10)
" 2>&1 | grep -c "Cannot create dictionary with empty layout"

# No PK
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    LAYOUT(COMPLEX_KEY_HASHED())
    SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' DB '$DATASTORE_DATABASE'))
    LIFETIME(MIN 1 MAX 10)
" 2>&1 | grep -c "Cannot create dictionary without primary key"

# No lifetime
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    PRIMARY KEY key2, key1
    LAYOUT(COMPLEX_KEY_HASHED())
    SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' DB '$DATASTORE_DATABASE'))
" 2>&1 | grep -c "Cannot create dictionary with empty lifetime"

# No source
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    PRIMARY KEY non_existing_column, key1
    LAYOUT(COMPLEX_KEY_HASHED())
    LIFETIME(MIN 1 MAX 10)
" 2>&1 | grep -c "Cannot create dictionary with empty source"


# Complex layout, but with one key
$DATASTORE_CLIENT -q "
    CREATE DICTIONARY dict1
    (
        key1 UInt64,
        key2 UInt64,
        value String
    )
    PRIMARY KEY key1
    LAYOUT(COMPLEX_KEY_HASHED())
    SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict1' DB '$DATASTORE_DATABASE'))
    LIFETIME(MIN 1 MAX 10)
" || exit 1


$DATASTORE_CLIENT -q "DROP DICTIONARY IF  EXISTS dict1"
