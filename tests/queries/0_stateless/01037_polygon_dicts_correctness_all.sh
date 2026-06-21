#!/usr/bin/env bash
# Tags: no-debug

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

TMP_DIR=${DATASTORE_TMP}/tmp
DATA_DIR=${DATASTORE_TMP}/data
mkdir -p $TMP_DIR
mkdir -p $DATA_DIR

declare -a SearchTypes=("POLYGON" "POLYGON_SIMPLE" "POLYGON_INDEX_EACH" "POLYGON_INDEX_CELL")

tar -xf "${CURDIR}"/01037_test_data_search.tar.gz -C "${DATA_DIR}"

$DATASTORE_CLIENT --query="
DROP TABLE IF EXISTS points;
CREATE TABLE points (x Float64, y Float64) ENGINE = Memory;
"

$DATASTORE_CLIENT --query="INSERT INTO points FORMAT TSV" --max_insert_block_size=100000 < "${DATA_DIR}/01037_point_data"

rm "${DATA_DIR}"/01037_point_data

$DATASTORE_CLIENT --query="
DROP TABLE IF EXISTS polygons_array;

CREATE TABLE polygons_array
(
   key Array(Array(Array(Array(Float64)))),
   name String,
   value UInt64
)
ENGINE = Memory;
"

$DATASTORE_CLIENT --query="INSERT INTO polygons_array FORMAT JSONEachRow" --min_chunk_bytes_for_parallel_parsing=10485760 --max_insert_block_size=100000 < "${DATA_DIR}/01037_polygon_data"

rm "${DATA_DIR}"/01037_polygon_data

for type in "${SearchTypes[@]}";
do
   outputFile="${TMP_DIR}/results${type}.out"

   $DATASTORE_CLIENT --query="
   DROP DICTIONARY IF EXISTS dict_array;

   CREATE DICTIONARY dict_array
   (
   key Array(Array(Array(Array(Float64)))),
   name String DEFAULT 'qqq',
   value UInt64 DEFAULT 101
   )
   PRIMARY KEY key
   SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'polygons_array' PASSWORD '' DB currentDatabase()))
   LIFETIME(0)
   LAYOUT($type());

   select 'dictGet', 'dict_array' as dict_name, tuple(x, y) as key,
      dictGet(dict_name, 'value', key) from points order by x, y;
   " > "$outputFile"

   diff -q "${CURDIR}/01037_polygon_dicts_correctness_all.ans" "$outputFile"
done
