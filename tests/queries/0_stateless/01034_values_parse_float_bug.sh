#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS values_floats"

${DATASTORE_CLIENT} --query="CREATE TABLE values_floats (a Float32, b Float64) ENGINE = Memory"

${DATASTORE_CLIENT} --query="SELECT '(-160.32605134916085,37.70584056842162),' FROM numbers(1000000)" | ${DATASTORE_CLIENT} --query="INSERT INTO values_floats FORMAT Values"

${DATASTORE_CLIENT} --query="SELECT DISTINCT round(a, 6), round(b, 6) FROM values_floats"

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS values_floats"

