#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select true::Bool as b format Avro" | $DATASTORE_LOCAL --table=test --input-format=Avro -q "select b, toTypeName(b) from test";

