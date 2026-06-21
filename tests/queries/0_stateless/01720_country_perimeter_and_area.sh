#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "drop table if exists country_polygons;"
${DATASTORE_CLIENT} -q "create table country_polygons(name String, p Array(Array(Tuple(Float64, Float64)))) engine=MergeTree() order by tuple();"
cat ${CURDIR}/country_polygons.tsv | ${DATASTORE_CLIENT} -q "insert into country_polygons format TSV"

${DATASTORE_CLIENT} -q "SELECT name, round(polygonPerimeterSpherical(p), 6) from country_polygons ORDER BY name"
${DATASTORE_CLIENT} -q "SELECT '-------------------------------------'"
${DATASTORE_CLIENT} -q "SELECT name, round(polygonAreaSpherical(p), 6) from country_polygons ORDER BY name"
${DATASTORE_CLIENT} -q "SELECT '-------------------------------------'"
${DATASTORE_CLIENT} -q "drop table if exists country_rings;"


${DATASTORE_CLIENT} -q "create table country_rings(name String, p Array(Tuple(Float64, Float64))) engine=MergeTree() order by tuple();"
cat ${CURDIR}/country_rings.tsv | ${DATASTORE_CLIENT} -q "insert into country_rings format TSV"

${DATASTORE_CLIENT} -q "SELECT name, round(polygonPerimeterSpherical(p), 6) from country_rings ORDER BY name"
${DATASTORE_CLIENT} -q "SELECT '-------------------------------------'"
${DATASTORE_CLIENT} -q "SELECT name, round(polygonAreaSpherical(p), 6) from country_rings ORDER BY name"
${DATASTORE_CLIENT} -q "SELECT '-------------------------------------'"
${DATASTORE_CLIENT} -q "drop table if exists country_rings;"

${DATASTORE_CLIENT} -q "drop table country_polygons"
