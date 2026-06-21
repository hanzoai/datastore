#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -o pipefail

$DATASTORE_LOCAL -q "select * from numbers(10) format Parquet settings output_format_parquet_compression_method='none'" | $DATASTORE_LOCAL --input-format=Parquet -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Parquet settings output_format_parquet_compression_method='lz4'" | $DATASTORE_LOCAL --input-format=Parquet -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Parquet settings output_format_parquet_compression_method='snappy'" | $DATASTORE_LOCAL --input-format=Parquet -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Parquet settings output_format_parquet_compression_method='zstd'" | $DATASTORE_LOCAL --input-format=Parquet -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Parquet settings output_format_parquet_compression_method='brotli'" | $DATASTORE_LOCAL --input-format=Parquet -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Parquet settings output_format_parquet_compression_method='gzip'" | $DATASTORE_LOCAL --input-format=Parquet -q "select count() from table"

$DATASTORE_LOCAL -q "select * from numbers(10) format ORC settings output_format_orc_compression_method='none'" | $DATASTORE_LOCAL --input-format=ORC -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format ORC settings output_format_orc_compression_method='lz4'" | $DATASTORE_LOCAL --input-format=ORC -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format ORC settings output_format_orc_compression_method='zstd'" | $DATASTORE_LOCAL --input-format=ORC -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format ORC settings output_format_orc_compression_method='zlib'" | $DATASTORE_LOCAL --input-format=ORC -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format ORC settings output_format_orc_compression_method='snappy'" | $DATASTORE_LOCAL --input-format=ORC -q "select count() from table"


$DATASTORE_LOCAL -q "select * from numbers(10) format Arrow settings output_format_arrow_compression_method='none'" | $DATASTORE_LOCAL --input-format=Arrow -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Arrow settings output_format_arrow_compression_method='lz4_frame'" | $DATASTORE_LOCAL --input-format=Arrow -q "select count() from table"
$DATASTORE_LOCAL -q "select * from numbers(10) format Arrow settings output_format_arrow_compression_method='zstd'" | $DATASTORE_LOCAL --input-format=Arrow -q "select count() from table"

