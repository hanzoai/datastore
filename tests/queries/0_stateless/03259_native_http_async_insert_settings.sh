#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


$DATASTORE_CLIENT -q "drop table if exists test"
$DATASTORE_CLIENT -q "create table test (x UInt32) engine=Memory";

url="${DATASTORE_URL}&async_insert=1&wait_for_async_insert=1"

$DATASTORE_LOCAL -q "select NULL::Nullable(UInt32) as x format Native" | ${DATASTORE_CURL} -sS "$url&query=INSERT%20INTO%20test%20FORMAT%20Native" --data-binary @-

$DATASTORE_CLIENT -q "select * from test";
$DATASTORE_CLIENT -q "drop table test"

