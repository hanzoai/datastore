#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_FORMAT --query "select json.^sub.object.path from test";
$DATASTORE_FORMAT --query "select json.^\`s^b\`.object.path from test";
$DATASTORE_FORMAT --query "select json.\`^sub\`.object.path from test";

$DATASTORE_FORMAT --query "select json.path.:UInt64 from test";
$DATASTORE_FORMAT --query "select json.path.:\`Array(JSON)\` from test";
$DATASTORE_FORMAT --query "select json.path.\`:UInt64\` from test";

