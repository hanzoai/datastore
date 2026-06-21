#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

SCHEMA_FILE=$DATASTORE_TEST_UNIQUE_NAME-schema

$DATASTORE_LOCAL -q "select 42 as col_1 format Protobuf settings output_format_schema='$SCHEMA_FILE.proto'" > /dev/null
tail -n +2 $SCHEMA_FILE.proto

$DATASTORE_LOCAL -q "select 42 as \`col.1\` format Protobuf" 2>&1 | grep -c -F "BAD_ARGUMENTS"
$DATASTORE_LOCAL -q "select 42 as \`col.1\` format CapnProto" 2>&1 | grep -c -F "BAD_ARGUMENTS"

rm $SCHEMA_FILE*

