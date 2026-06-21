#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS orc_lc";


$DATASTORE_CLIENT --query="CREATE TABLE orc_lc (lc LowCardinality(String), array_lc Array(LowCardinality(String)), tuple_lc  Tuple(LowCardinality(String))) ENGINE = Memory()";


$DATASTORE_CLIENT --query="SELECT [lc] as array_lc, tuple(lc) as tuple_lc, toLowCardinality(toString(number)) as lc from numbers(10) FORMAT ORC" | $DATASTORE_CLIENT --query="INSERT INTO orc_lc FORMAT ORC";

$DATASTORE_CLIENT --query="SELECT * FROM orc_lc";
