#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

FUNCTION_NAME="function_$DATASTORE_DATABASE"

$DATASTORE_CLIENT -q "
  DROP FUNCTION IF EXISTS $FUNCTION_NAME;
  DROP TABLE IF EXISTS t;
"

$DATASTORE_CLIENT -q "
  CREATE FUNCTION $FUNCTION_NAME AS (x) -> (x AS c0);
  CREATE FUNCTION ${FUNCTION_NAME}_col AS () -> COLUMNS('');
  CREATE TABLE t (t0 UInt64, t1 UInt64) ENGINE=MergeTree() ORDER BY t0;
"

$DATASTORE_CLIENT -q "CREATE VIEW x AS (SELECT $FUNCTION_NAME(*)); -- { serverError BAD_ARGUMENTS }"
$DATASTORE_CLIENT -q "CREATE VIEW x AS (SELECT $FUNCTION_NAME(t.*) FROM t); -- { serverError BAD_ARGUMENTS }"
$DATASTORE_CLIENT -q "CREATE VIEW x AS (SELECT $FUNCTION_NAME(COLUMNS(''))); -- { serverError BAD_ARGUMENTS }"
$DATASTORE_CLIENT -q "CREATE VIEW x AS (SELECT $FUNCTION_NAME(COLUMNS('t.*'))); -- { serverError BAD_ARGUMENTS }"
$DATASTORE_CLIENT -q "CREATE VIEW x AS (SELECT $FUNCTION_NAME(COLUMNS('t.t*')) FROM t); -- { serverError BAD_ARGUMENTS }"
$DATASTORE_CLIENT -q "CREATE VIEW x AS (SELECT ${FUNCTION_NAME}_col() AS c0); -- { serverError BAD_ARGUMENTS }"

# Using UDF normally should work (but it didn't with the old analyzer).
# Feel free to delete it in the future if this changes
$DATASTORE_CLIENT --enable-analyzer=1 -q "
  SELECT COLUMNS('t*') APPLY $FUNCTION_NAME FROM t;
  SELECT $FUNCTION_NAME(COLUMNS('t1')) FROM t;
"

$DATASTORE_CLIENT -q "
  DROP FUNCTION IF EXISTS $FUNCTION_NAME;
  DROP TABLE IF EXISTS t;
"