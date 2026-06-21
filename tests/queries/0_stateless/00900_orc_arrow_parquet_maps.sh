#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS maps"
${DATASTORE_CLIENT} <<EOF
CREATE TABLE maps (m1 Map(UInt32, UInt32), m2 Map(String, String), m3 Map(UInt32, Tuple(UInt32, UInt32)), m4 Map(UInt32, Array(UInt32)), m5 Array(Map(UInt32, UInt32)), m6 Tuple(Map(UInt32, UInt32), Map(String, String)), m7 Array(Map(UInt32, Array(Tuple(Map(UInt32, UInt32), Tuple(UInt32)))))) ENGINE=Memory();
EOF

${DATASTORE_CLIENT} --query="INSERT INTO maps VALUES ({1 : 2, 2 : 3}, {'1' : 'a', '2' : 'b'}, {1 : (1, 2), 2 : (3, 4)}, {1 : [1, 2], 2 : [3, 4]}, [{1 : 2, 2 : 3}, {3 : 4, 4 : 5}], ({1 : 2, 2 : 3}, {'a' : 'b', 'c' : 'd'}), [{1 : [({1 : 2}, (1)), ({2 : 3}, (2))]}, {2 : [({3 : 4}, (3)), ({4 : 5}, (4))]}])"


formats="Arrow Parquet ORC";


for format in ${formats}; do
    echo $format
    
    ${DATASTORE_CLIENT} --query="SELECT * FROM maps FORMAT $format" > "${DATASTORE_TMP}"/maps
    ${DATASTORE_CLIENT} --query="TRUNCATE TABLE maps"
    cat "${DATASTORE_TMP}"/maps | ${DATASTORE_CLIENT} -q "INSERT INTO maps FORMAT $format"
    ${DATASTORE_CLIENT} --query="SELECT * FROM maps"
done

${DATASTORE_CLIENT} --query="DROP TABLE maps"
