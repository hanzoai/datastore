#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_LOCAL} -q "insert into function file('${DATASTORE_TMP}/t0.parquet') select * from numbers(10)"
for i in {1..99}
do
    cp "${DATASTORE_TMP}/t0.parquet" "${DATASTORE_TMP}/t${i}.parquet"
done

${DATASTORE_LOCAL} -q "select sum(number) from file('${DATASTORE_TMP}/t{0..99}.parquet') settings input_format_parquet_preserve_order=1"

rm "${DATASTORE_TMP}"/t{0..99}.parquet
