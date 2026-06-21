#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "create table test (key Int) engine=Null"
uuid=$($DATASTORE_CLIENT -q "select uuid from system.tables where name = 'test' and database = '$DATASTORE_DATABASE'")
$DATASTORE_CLIENT -q "select database, name from system.tables where uuid = '$uuid'"
