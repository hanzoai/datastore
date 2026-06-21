#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 42 as x format Native" > $DATASTORE_TEST_UNIQUE_NAME.native
$DATASTORE_LOCAL -q "
create table test (x UInt64, y UInt64) engine=Memory;
insert into test (x) select * from file('$DATASTORE_TEST_UNIQUE_NAME.native');
insert into test (y) select * from file('$DATASTORE_TEST_UNIQUE_NAME.native');
insert into test (* except(x)) select * from file('$DATASTORE_TEST_UNIQUE_NAME.native');
insert into test (* except(y)) select * from file('$DATASTORE_TEST_UNIQUE_NAME.native');
select * from test order by x;
"

rm $DATASTORE_TEST_UNIQUE_NAME.native

$DATASTORE_LOCAL -q "select 'world' as y, 42 as x format Values" > $DATASTORE_TEST_UNIQUE_NAME.values
$DATASTORE_CLIENT -q "
drop table if exists test_infile;
create table test_infile (val UInt64, key String) engine=Memory;
insert into test_infile from infile '$DATASTORE_TEST_UNIQUE_NAME.values' FORMAT Values; -- { clientError CANNOT_PARSE_TEXT }
insert into test_infile (key, val) from infile '$DATASTORE_TEST_UNIQUE_NAME.values' FORMAT Values;
insert into test_infile (* EXCEPT 'val', * EXCEPT 'key') from infile '$DATASTORE_TEST_UNIQUE_NAME.values' FORMAT Values;
insert into test_infile (* EXCEPT 'val', test_infile.val) from infile '$DATASTORE_TEST_UNIQUE_NAME.values' FORMAT Values;
insert into table function remote('localhost:9000', $DATASTORE_DATABASE.test_infile) (remote.key, _table_function.remote.val) from infile '$DATASTORE_TEST_UNIQUE_NAME.values' FORMAT Values;
select * from test_infile order by key, val;
"

rm $DATASTORE_TEST_UNIQUE_NAME.values
