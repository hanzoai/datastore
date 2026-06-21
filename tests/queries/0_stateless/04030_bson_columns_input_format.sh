#!/usr/bin/env bash

# NOTE: this sh wrapper is required because of shell_config

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Base case for auto case
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (id Int, ID Int, name String, NaMe String)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='auto';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_names.bson' FORMAT BSONEachRow;"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"

# Test ambiguity for automatic column name matching
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (id Int, iD Int, name String, NAME String)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='auto';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_names.bson' FORMAT BSONEachRow; -- { clientError 117 }"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"

# Base case for match case
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (id Int, ID Int, name String, NaMe String)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='match_case';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_names.bson' FORMAT BSONEachRow;"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"

# Base case for ignore case
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (ID Int, name String)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='ignore_case';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_names_no_duplicates.bson' FORMAT BSONEachRow;"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"

# Test ambiguity for ignore case column name matching
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (id Int, ID Int, name String, NAME String)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='ignore_case';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_names.bson' FORMAT BSONEachRow; -- { clientError 117 }"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"

# Test ambiguity when two input columns map to the same table column (auto case match)
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (id Int)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='auto';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_duplicated_names.bson' FORMAT BSONEachRow; -- { clientError 117 }"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"

# Test ambiguity when two input columns map to the same table column (ignore case match)
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "CREATE TABLE test (id Int)"
$DATASTORE_CLIENT -q "SET input_format_column_name_matching_mode='ignore_case';
                       INSERT INTO test FROM INFILE '$CURDIR/data_bson/bson_with_duplicated_names.bson' FORMAT BSONEachRow; -- { clientError 117 }"
$DATASTORE_CLIENT -q "SELECT * FROM test"
$DATASTORE_CLIENT -q "DROP TABLE test"