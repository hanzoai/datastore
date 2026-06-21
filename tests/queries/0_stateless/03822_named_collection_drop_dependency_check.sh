#!/usr/bin/env bash
# Tags: no-fasttest, no-replicated-database

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

ORDINARY_DB="${DATASTORE_DATABASE}_ordinary"
NC_NAME="test_nc_dep_${DATASTORE_DATABASE}"

# Setup: clean up any leftover state
$DATASTORE_CLIENT -m -q "
SET check_named_collection_dependencies = false;
DROP NAMED COLLECTION IF EXISTS ${NC_NAME};
"

# Create named collection and table that uses it
$DATASTORE_CLIENT -m -q "
CREATE NAMED COLLECTION ${NC_NAME} AS url = 'http://localhost:8123', format = 'CSV';
CREATE TABLE test_nc_dep_table (x UInt32) ENGINE = URL(${NC_NAME});
"

# Should fail because table uses the named collection (check_named_collection_dependencies is true by default)
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"

# With check_named_collection_dependencies disabled, drop should succeed even with dependent table
$DATASTORE_CLIENT -m -q "
SET check_named_collection_dependencies = false;
DROP NAMED COLLECTION ${NC_NAME};
DROP TABLE test_nc_dep_table;
"

# Test normal behavior again with the setting enabled
$DATASTORE_CLIENT -m -q "
CREATE NAMED COLLECTION ${NC_NAME} AS url = 'http://localhost:8123', format = 'CSV';
CREATE TABLE test_nc_dep_table (x UInt32) ENGINE = URL(${NC_NAME});
"

# Should fail again with setting enabled
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Test rename: dependency should be tracked after rename (Atomic database uses UUID, so rename is transparent)
$DATASTORE_CLIENT -q "RENAME TABLE test_nc_dep_table TO test_nc_dep_table_renamed;"
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Test EXCHANGE TABLES in Atomic database (UUID-based tracking handles this automatically)
NC_NAME2="test_nc_dep2_${DATASTORE_DATABASE}"
$DATASTORE_CLIENT -m -q "
SET check_named_collection_dependencies = false;
DROP NAMED COLLECTION IF EXISTS ${NC_NAME2};
"
$DATASTORE_CLIENT -m -q "
CREATE NAMED COLLECTION ${NC_NAME2} AS url = 'http://localhost:8123', format = 'JSON';
CREATE TABLE test_nc_dep_table2 (x UInt32) ENGINE = URL(${NC_NAME2});
"

# Both named collections should be protected
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME2}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Exchange the tables - dependencies should still work (UUID-based tracking)
$DATASTORE_CLIENT -q "EXCHANGE TABLES test_nc_dep_table_renamed AND test_nc_dep_table2;"

# After exchange, both named collections should still be protected
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME2}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Clean up
$DATASTORE_CLIENT -m -q "
DROP TABLE test_nc_dep_table_renamed;
DROP TABLE test_nc_dep_table2;
DROP NAMED COLLECTION ${NC_NAME};
DROP NAMED COLLECTION ${NC_NAME2};
"

# Test with mixed databases: one table in Atomic, one in Ordinary, both using the same named collection
# This tests both UUID-based and name-based tracking simultaneously
# Use --send_logs_level=error to suppress the deprecation warning for Ordinary database
$DATASTORE_CLIENT --send_logs_level=error -m -q "
SET allow_deprecated_database_ordinary = 1;
DROP DATABASE IF EXISTS ${ORDINARY_DB};
CREATE DATABASE ${ORDINARY_DB} ENGINE = Ordinary;
"

$DATASTORE_CLIENT -m -q "
CREATE NAMED COLLECTION ${NC_NAME} AS url = 'http://localhost:8123', format = 'CSV';
CREATE TABLE test_nc_dep_atomic (x UInt32) ENGINE = URL(${NC_NAME});
CREATE TABLE ${ORDINARY_DB}.test_nc_dep_ordinary (x UInt32) ENGINE = URL(${NC_NAME});
"

# Should fail because both tables use the named collection
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Test rename in Ordinary database (name-based tracking should update)
$DATASTORE_CLIENT -q "RENAME TABLE ${ORDINARY_DB}.test_nc_dep_ordinary TO ${ORDINARY_DB}.test_nc_dep_ordinary_renamed;"
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Drop the Atomic table, should still fail because Ordinary table uses the collection
$DATASTORE_CLIENT -q "DROP TABLE test_nc_dep_atomic;"
$DATASTORE_CLIENT -m -q "DROP NAMED COLLECTION ${NC_NAME}; -- { serverError NAMED_COLLECTION_IS_USED }"

# Drop the Ordinary table, now drop should succeed
$DATASTORE_CLIENT -m -q "
DROP TABLE ${ORDINARY_DB}.test_nc_dep_ordinary_renamed;
DROP NAMED COLLECTION ${NC_NAME};
DROP DATABASE ${ORDINARY_DB};
"
