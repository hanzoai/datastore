#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="SELECT * from numbers(1)"
$DATASTORE_CLIENT --query="SELECT * from format('TSV', '123')"

$DATASTORE_CLIENT --readonly=1 --query="SELECT * from numbers(1)"
$DATASTORE_CLIENT --readonly=1 --query="SELECT * from format('TSV', '123')" 2>&1 | grep -Fq "Cannot execute query in readonly mode. (READONLY)" && echo 'ERROR' || echo 'OK'
$DATASTORE_CLIENT --readonly=1 --query="INSERT INTO FUNCTION null('x String') (x) FORMAT TSV '123'" 2>&1 | grep -Fq "Cannot execute query in readonly mode. (READONLY)" && echo 'ERROR' || echo 'OK'
