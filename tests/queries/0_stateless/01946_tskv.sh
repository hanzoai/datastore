#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS tskv";
$DATASTORE_CLIENT --query="CREATE TABLE tskv (text String) ENGINE = Memory";

# shellcheck disable=SC2028
echo -n 'tskv	text=can contain \= symbol
' | $DATASTORE_CLIENT --query="INSERT INTO tskv FORMAT TSKV";

$DATASTORE_CLIENT --query="SELECT * FROM tskv";
$DATASTORE_CLIENT --query="DROP TABLE tskv";
