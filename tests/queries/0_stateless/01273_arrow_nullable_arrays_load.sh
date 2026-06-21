#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_nullable_arrays"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_nullable_arrays (arr1 Array(Nullable(UInt32)), arr2 Array(Nullable(String)), arr3 Array(Nullable(Float32))) ENGINE=Memory()"
${DATASTORE_CLIENT} --query="INSERT INTO arrow_nullable_arrays VALUES ([1,NULL,2],[NULL,'Some string',NULL],[0.00,NULL,42.42]), ([NULL],[NULL],[NULL]), ([],[],[])"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_nullable_arrays FORMAT Arrow" > "${DATASTORE_TMP}"/nullable_arrays.arrow

cat "${DATASTORE_TMP}"/nullable_arrays.arrow | ${DATASTORE_CLIENT} -q "INSERT INTO arrow_nullable_arrays FORMAT Arrow"

${DATASTORE_CLIENT} --query="SELECT * FROM arrow_nullable_arrays"
${DATASTORE_CLIENT} --query="DROP TABLE arrow_nullable_arrays"
