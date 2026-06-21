#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "drop table if exists country_polygons;"
${DATASTORE_CLIENT} -q "create table country_polygons(name String, p Array(Array(Tuple(Float64, Float64)))) engine=Memory()"
cat ${CURDIR}/country_polygons.tsv | ${DATASTORE_CLIENT} -q "insert into country_polygons format TSV"
${DATASTORE_CLIENT} -q "SELECT c, d, polygonsIntersectionSpherical(a, b) FROM (SELECT first.p AS a, second.p AS b, first.name AS c, second.name AS d FROM country_polygons AS first CROSS JOIN country_polygons AS second LIMIT 100) format TSV"
${DATASTORE_CLIENT} -q "drop table if exists country_polygons;"


${DATASTORE_CLIENT} -q "drop table if exists country_rings;"
${DATASTORE_CLIENT} -q "create table country_rings(name String, p Array(Tuple(Float64, Float64))) engine=Memory()"
cat ${CURDIR}/country_rings.tsv | ${DATASTORE_CLIENT} -q "insert into country_rings format TSV"
${DATASTORE_CLIENT} -q "SELECT c, d, polygonsIntersectionSpherical(a, b) FROM (SELECT first.p AS a, second.p AS b, first.name AS c, second.name AS d FROM country_rings AS first CROSS JOIN country_rings AS second WHERE c = 'Aruba') ORDER BY d LIMIT 10 format TSV"
${DATASTORE_CLIENT} -q "drop table if exists country_rings;"
