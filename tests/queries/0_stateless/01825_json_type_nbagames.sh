#!/usr/bin/env bash
# Tags: no-fasttest, long, no-flaky-check

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# Pin date_time_input_format to 'basic' so JSON path inference matches the
# pre-existing reference (best_effort would infer DateTime64 from ISO date strings).
DATASTORE_CLIENT="${DATASTORE_CLIENT} --date_time_input_format=basic"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS nbagames"
${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS nbagames_string"
${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS nbagames_from_string"

${DATASTORE_CLIENT} -q "CREATE TABLE nbagames (data JSON) ENGINE = MergeTree ORDER BY tuple()" --enable_json_type 1

cat $CUR_DIR/data_json/nbagames_sample.json | ${DATASTORE_CLIENT} -q "INSERT INTO nbagames FORMAT JSONAsObject"

${DATASTORE_CLIENT} -q "SELECT count() FROM nbagames WHERE NOT ignore(*)"
${DATASTORE_CLIENT} -q "SELECT DISTINCT arrayJoin(JSONAllPathsWithTypes(data)) as path from nbagames order by path"
${DATASTORE_CLIENT} -q "SELECT DISTINCT arrayJoin(JSONAllPathsWithTypes(arrayJoin(data.teams[]))) as path from nbagames order by path"

${DATASTORE_CLIENT} --enable_analyzer=1 -q  \
    "SELECT teams.name.:String AS name, sum(teams.won.:Int64) AS wins FROM nbagames \
    ARRAY JOIN data.teams[] AS teams GROUP BY name \
    ORDER BY wins DESC LIMIT 5;"

${DATASTORE_CLIENT} -q "SELECT DISTINCT arrayJoin(JSONAllPathsWithTypes(arrayJoin(arrayJoin(data.teams[].players[])))) as path from nbagames order by path"

${DATASTORE_CLIENT} --enable_analyzer=1 -q \
"SELECT player, sum(triple_double) AS triple_doubles FROM \
( \
    SELECT \
        arrayJoin(arrayJoin(data.teams[].players[])) as players, \
        players.player.:String as player, \
        ((players.pts.:Int64 >= 10) + \
        (players.ast.:Int64 >= 10) + \
        (players.blk.:Int64 >= 10) + \
        (players.stl.:Int64 >= 10) + \
        (players.trb.:Int64 >= 10)) >= 3 AS triple_double \
        from nbagames \
) \
GROUP BY player ORDER BY triple_doubles DESC, player LIMIT 5"

${DATASTORE_CLIENT} -q "CREATE TABLE nbagames_string (data String) ENGINE = MergeTree ORDER BY tuple()"
${DATASTORE_CLIENT} -q "CREATE TABLE nbagames_from_string (data JSON) ENGINE = MergeTree ORDER BY tuple()" --enable_json_type 1

cat $CUR_DIR/data_json/nbagames_sample.json | ${DATASTORE_CLIENT} -q "INSERT INTO nbagames_string FORMAT JSONAsString"
${DATASTORE_CLIENT} -q "INSERT INTO nbagames_from_string SELECT data FROM nbagames_string"

${DATASTORE_CLIENT} -q "SELECT \
    (SELECT groupUniqArrayMap(JSONAllPathsWithTypes(data)), sum(cityHash64(toString(data))) FROM nbagames_from_string) = \
    (SELECT groupUniqArrayMap(JSONAllPathsWithTypes(data)), sum(cityHash64(toString(data))) FROM nbagames)"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS nbagames"
${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS nbagames_string"
${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS nbagames_from_string"
