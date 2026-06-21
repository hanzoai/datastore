#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS orc_nested_arrays"
${DATASTORE_CLIENT} --query="CREATE TABLE orc_nested_arrays (arr1 Array(Array(Array(UInt32))), arr2 Array(Array(Array(String))), arr3 Array(Array(Nullable(UInt32))), arr4 Array(Array(Nullable(String)))) engine=Memory()"

${DATASTORE_CLIENT} --query="INSERT INTO orc_nested_arrays VALUES ([[[1,2,3],[1,2,3]],[[1,2,3]],[[],[1,2,3]]],[[['Some string','Some string'],[]],[['Some string']],[[]]],[[NULL,1,2],[NULL],[1,2],[]],[['Some string',NULL,'Some string'],[NULL],[]])"

${DATASTORE_CLIENT} --query="SELECT * FROM orc_nested_arrays FORMAT ORC" > "${DATASTORE_TMP}"/nested_arrays.orc

cat "${DATASTORE_TMP}"/nested_arrays.orc | ${DATASTORE_CLIENT} -q "INSERT INTO orc_nested_arrays FORMAT ORC"

${DATASTORE_CLIENT} --query="SELECT * FROM orc_nested_arrays"
${DATASTORE_CLIENT} --query="DROP table orc_nested_arrays"
