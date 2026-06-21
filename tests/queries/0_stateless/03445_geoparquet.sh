#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_parquet/03445_geoparquet_wkb.parquet', Parquet)"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_parquet/03445_geoparquet_wkt.parquet', Parquet)"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_parquet/03445_geoparquet_null_point.parquet', Parquet)"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_parquet/03445_geoparquet_null_linestring.parquet', Parquet)"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_parquet/03445_geoparquet_null_polygon.parquet', Parquet)"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_parquet/03445_geoparquet_wkb.parquet', Parquet) SETTINGS input_format_parquet_allow_geoparquet_parser=false;"
$DATASTORE_LOCAL -q "select toTypeName(point_id), toTypeName(line_id), toTypeName(polygon_id), toTypeName(multilines_id), toTypeName(multipolygons_id) from file('$CURDIR/data_parquet/03445_geoparquet_wkb.parquet', Parquet);"
