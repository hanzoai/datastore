#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 1 as x format Native" > $DATASTORE_TEST_UNIQUE_NAME.native
$DATASTORE_LOCAL -q "
create table test (x UInt64, y UInt64 default 42) engine=Memory;
insert into test select * from file('$DATASTORE_TEST_UNIQUE_NAME.native');
select * from test;
"

rm $DATASTORE_TEST_UNIQUE_NAME.native
