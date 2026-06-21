#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "
CREATE FUNCTION linear_equation AS (x, k, b) -> ((k * x) + b);

DROP FUNCTION linear_equation ON CLUSTER test;
" | ${DATASTORE_FORMAT} --multiquery

echo "CREATE FUNCTION linear_equation AS (x, k, b) -> ((k * x) + b); DROP FUNCTION linear_equation;" | $DATASTORE_FORMAT -n
echo "CREATE FUNCTION linear_equation AS (x, k, b) -> ((k * x) + b); DROP FUNCTION linear_equation ON CLUSTER test" | $DATASTORE_FORMAT -n
echo "CREATE FUNCTION linear_equation AS (x, k, b) -> ((k * x) + b); DROP FUNCTION linear_equation ON CLUSTER test;" | $DATASTORE_FORMAT -n
echo "CREATE FUNCTION linear_equation AS (x, k, b) -> ((k * x) + b); DROP FUNCTION linear_equation ON CLUSTER test; CREATE FUNCTION linear_equation AS (x, k, b) -> ((k * x) + b);" | $DATASTORE_FORMAT -n
