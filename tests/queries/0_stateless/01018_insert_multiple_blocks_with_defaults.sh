#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS defaults"
$DATASTORE_CLIENT --query="CREATE TABLE defaults (n UInt8, s String DEFAULT 'hello') ENGINE = Memory"
echo '{"n": 1} {"n": 2, "s":"world"}' | $DATASTORE_CLIENT --max_insert_block_size=1 --query="INSERT INTO defaults FORMAT JSONEachRow"
$DATASTORE_CLIENT --query="SELECT * FROM defaults ORDER BY n"
$DATASTORE_CLIENT --query="DROP TABLE defaults"
