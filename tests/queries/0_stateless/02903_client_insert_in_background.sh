#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "drop table if exists test"
$DATASTORE_CLIENT -q "create table test (x UInt64) engine=Memory"
nohup $DATASTORE_CLIENT -q "insert into test values (42)" 2> $DATASTORE_TEST_UNIQUE_NAME.out
tail -n +2 $DATASTORE_TEST_UNIQUE_NAME.out
$DATASTORE_CLIENT -q "drop table test"
rm $DATASTORE_TEST_UNIQUE_NAME.out

