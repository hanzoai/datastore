#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select * from numbers(3) format Parquet" | $DATASTORE_LOCAL --input-format=Parquet --table=test -q "desc test" --schema_inference_make_columns_nullable=1;
$DATASTORE_LOCAL -q "select * from numbers(3) format Parquet" | $DATASTORE_LOCAL --input-format=Parquet --table=test -q "desc test" --schema_inference_make_columns_nullable=0;

$DATASTORE_LOCAL -q "select * from numbers(3) format ORC" | $DATASTORE_LOCAL --input-format=ORC --table=test -q "desc test" --schema_inference_make_columns_nullable=1;
$DATASTORE_LOCAL -q "select * from numbers(3) format ORC" | $DATASTORE_LOCAL --input-format=ORC --table=test -q "desc test" --schema_inference_make_columns_nullable=0;

$DATASTORE_LOCAL -q "select * from numbers(3) format Arrow" | $DATASTORE_LOCAL --input-format=Arrow --table=test -q "desc test" --schema_inference_make_columns_nullable=1;
$DATASTORE_LOCAL -q "select * from numbers(3) format Arrow" | $DATASTORE_LOCAL --input-format=Arrow --table=test -q "desc test" --schema_inference_make_columns_nullable=0;

