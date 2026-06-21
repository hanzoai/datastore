#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "desc file('$CURDIR/data_bson/comments.bson')"
$DATASTORE_LOCAL -q "select _id from file('$CURDIR/data_bson/comments.bson') format Null"

