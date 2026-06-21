#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select toBool(number % 2) as x from numbers(5) format Arrow" | $DATASTORE_LOCAL --input-format=Arrow -q "select x, toTypeName(x) from table";
$DATASTORE_LOCAL -q "select toBool(number % 2) as x from numbers(5) format Parquet" | $DATASTORE_LOCAL --input-format=Parquet -q "select x, toTypeName(x) from table";
$DATASTORE_LOCAL -q "select toBool(number % 2) as x from numbers(5) format ORC" | $DATASTORE_LOCAL --input-format=ORC -q "select x, toTypeName(x) from table";

