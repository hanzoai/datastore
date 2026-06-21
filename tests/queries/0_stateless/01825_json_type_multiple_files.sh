#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

for f in "${USER_FILES_PATH:?}/${DATASTORE_DATABASE}"_*.json; do
    [ -e $f ] && rm $f
done

for i in {0..5}; do
    echo "{\"k$i\": 100}" > "$USER_FILES_PATH/${DATASTORE_DATABASE}_$i.json"
done

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS t_json_files"
${DATASTORE_CLIENT} -q "CREATE TABLE t_json_files (file String, data JSON) ENGINE = MergeTree ORDER BY tuple()" --enable_json_type 1

${DATASTORE_CLIENT} -q "INSERT INTO t_json_files SELECT _file, data FROM file('${DATASTORE_DATABASE}_*.json', 'JSONAsObject', 'data JSON')" --enable_json_type 1

${DATASTORE_CLIENT} -q "SELECT data FROM t_json_files ORDER BY file FORMAT JSONEachRow" --output_format_json_named_tuples_as_objects 1
${DATASTORE_CLIENT} -q "SELECT DISTINCT arrayJoin(JSONAllPathsWithTypes(data)) AS path FROM t_json_files ORDER BY path"

${DATASTORE_CLIENT} -q "TRUNCATE TABLE IF EXISTS t_json_files"

${DATASTORE_CLIENT} -q "INSERT INTO t_json_files \
    SELECT _file, data FROM file('${DATASTORE_DATABASE}_*.json', 'JSONAsObject', 'data JSON') \
    ORDER BY _file LIMIT 3" --max_threads 1 --min_insert_block_size_rows 1 --max_insert_block_size 1 --max_block_size 1 --enable_json_type 1

${DATASTORE_CLIENT} -q "SELECT data FROM t_json_files ORDER BY file FORMAT JSONEachRow" --output_format_json_named_tuples_as_objects 1
${DATASTORE_CLIENT} -q "SELECT DISTINCT arrayJoin(JSONAllPathsWithTypes(data)) AS path FROM t_json_files ORDER BY path"

${DATASTORE_CLIENT} -q "TRUNCATE TABLE IF EXISTS t_json_files"

${DATASTORE_CLIENT} -q "INSERT INTO t_json_files \
    SELECT _file, data FROM file('${DATASTORE_DATABASE}_*.json', 'JSONAsObject', 'data JSON') \
    WHERE _file IN ('${DATASTORE_DATABASE}_1.json', '${DATASTORE_DATABASE}_3.json')" --enable_json_type 1

${DATASTORE_CLIENT} -q "SELECT data FROM t_json_files ORDER BY file FORMAT JSONEachRow" --output_format_json_named_tuples_as_objects 1
${DATASTORE_CLIENT} -q "SELECT DISTINCT arrayJoin(JSONAllPathsWithTypes(data)) AS path FROM t_json_files ORDER BY path"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS t_json_files"
rm "$USER_FILES_PATH"/${DATASTORE_DATABASE}_*.json
