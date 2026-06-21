#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists test"
$DATASTORE_CLIENT -q "create table test(x UInt32, y UInt32) engine=Memory"

echo -ne '{"meta":[{"name":"x","type":"UInt32"}, {"name":"y", "type":"UInt32"}],"data":{"x":[1,2,3],"y":[4,5,6]}}\n' | ${DATASTORE_CURL} -sS "{$DATASTORE_URL}&query=INSERT%20INTO%20test%20FORMAT%20JSONColumnsWithMetadata" --data-binary @-

$DATASTORE_CLIENT -q "select * from test"
$DATASTORE_CLIENT -q "drop table test"

