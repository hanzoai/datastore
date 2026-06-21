#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists test_02097" 
$DATASTORE_CLIENT -q "create table test_02097 (s String, f FixedString(8)) engine=Memory()"
echo -e "('test\n\t\0\n', 'test\n\t\0\n')" | $DATASTORE_CLIENT -q "insert into test_02097 format Values"
$DATASTORE_CLIENT -q "select * from test_02097 format JSONStringsEachRow" | $DATASTORE_CLIENT -q "insert into test_02097 format JSONStringsEachRow"
$DATASTORE_CLIENT -q "select * from test_02097 format JSONCompactStringsEachRow" | $DATASTORE_CLIENT -q "insert into test_02097 format JSONCompactStringsEachRow"
$DATASTORE_CLIENT -q "select * from test_02097"
$DATASTORE_CLIENT -q "drop table test_02097" 

