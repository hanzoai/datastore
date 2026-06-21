#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select number as x from numbers(5) format JSONEachRow" > $DATASTORE_TEST_UNIQUE_NAME.jsonl
$DATASTORE_LOCAL -q "select * from file('$DATASTORE_TEST_UNIQUE_NAME.jsonl', auto, 'x UInt64 Ephemeral, y UInt64 default x + 1')" 2>&1 | grep -c "BAD_ARGUMENTS"
$DATASTORE_LOCAL -q "select * from file('$DATASTORE_TEST_UNIQUE_NAME.jsonl', auto, 'x UInt64 Alias y, y UInt64')" 2>&1 | grep -c "BAD_ARGUMENTS"
$DATASTORE_LOCAL -q "select * from file('$DATASTORE_TEST_UNIQUE_NAME.jsonl', auto, 'x UInt64 Materialized 42, y UInt64')" 2>&1 | grep -c "BAD_ARGUMENTS"

$DATASTORE_LOCAL -q "
    create table test (x UInt64 Ephemeral, y UInt64 default x + 1) engine=Memory;
    insert into test (x, y) select * from file('$DATASTORE_TEST_UNIQUE_NAME.jsonl');
    select * from test;
    truncate table test;
    insert into test (x, y) from infile '$DATASTORE_TEST_UNIQUE_NAME.jsonl';
    select * from test
"

rm  $DATASTORE_TEST_UNIQUE_NAME.jsonl

