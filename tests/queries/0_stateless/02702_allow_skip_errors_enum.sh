#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "DROP TABLE IF EXISTS t; CREATE TABLE t (x Enum('Hello' = 1, 'World' = 2)) ENGINE = Memory;"
$DATASTORE_CLIENT --input_format_allow_errors_num 1 --query "INSERT INTO t FORMAT CSV" <<END
Hello
Goodbye
World
END

$DATASTORE_CLIENT --query "SELECT x FROM t ORDER BY x"
$DATASTORE_CLIENT --query "DROP TABLE t"
