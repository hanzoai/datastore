#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

FILE_PREFIX="${DATASTORE_USER_FILES_UNIQUE:?}_test_03277"

function cleanup()
{
       rm "${FILE_PREFIX:?}"*
}
trap cleanup EXIT


FILE_CSV="${FILE_PREFIX}.csv"
FILE_ARROW="${FILE_PREFIX}.arrow"


$DATASTORE_CLIENT -q "
    SET async_insert = 1;
    CREATE TABLE t0 (c0 Int) ENGINE = File(CSV);
    INSERT INTO TABLE t0 (c0) VALUES (1);
    INSERT INTO TABLE FUNCTION file('$FILE_CSV', 'CSV', 'c0 Int') SELECT c0 FROM t0;
    INSERT INTO TABLE t0 (c0) FROM INFILE '$FILE_CSV' FORMAT CSV;
"
$DATASTORE_CLIENT -q "SELECT * from t0"
$DATASTORE_CLIENT -q "DROP TABLE t0"


$DATASTORE_CLIENT -q "
    SET async_insert = 1;
    CREATE TABLE t0 (c0 Int) ENGINE = Join(ANY, INNER, c0);
    INSERT INTO TABLE FUNCTION file('$FILE_ARROW', 'Arrow', 'c0 Int') SELECT c0 FROM t0;
    INSERT INTO TABLE t0 (c0) FROM INFILE '$FILE_ARROW' FORMAT Arrow;
"
$DATASTORE_CLIENT -q "SELECT * from t0"
$DATASTORE_CLIENT -q "DROP TABLE t0"