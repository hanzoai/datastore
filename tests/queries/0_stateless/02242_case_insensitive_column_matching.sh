#!/usr/bin/env bash
# Tags: no-ubsan, no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo "Parquet"
DATA_FILE=$CUR_DIR/data_parquet/case_insensitive_column_matching.parquet
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS parquet_load"
${DATASTORE_CLIENT} --query="CREATE TABLE parquet_load (iD String, scOre Int32) ENGINE = Memory"
cat "$DATA_FILE" | ${DATASTORE_CLIENT} -q "INSERT INTO parquet_load SETTINGS input_format_parquet_case_insensitive_column_matching=true FORMAT Parquet"
${DATASTORE_CLIENT} --query="SELECT * FROM parquet_load"
${DATASTORE_CLIENT} --query="drop table parquet_load"

echo "ORC"
DATA_FILE=$CUR_DIR/data_orc/case_insensitive_column_matching.orc
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS orc_load"
${DATASTORE_CLIENT} --query="CREATE TABLE orc_load (iD String, sCorE Int32) ENGINE = Memory"
cat "$DATA_FILE" | ${DATASTORE_CLIENT} -q "INSERT INTO orc_load SETTINGS input_format_orc_case_insensitive_column_matching=true FORMAT ORC"
${DATASTORE_CLIENT} --query="SELECT * FROM orc_load"
${DATASTORE_CLIENT} --query="drop table orc_load"

echo "Arrow"
DATA_FILE=$CUR_DIR/data_arrow/case_insensitive_column_matching.arrow
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_load"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_load (iD String, sCorE Int32) ENGINE = Memory"
cat "$DATA_FILE" | ${DATASTORE_CLIENT} -q "INSERT INTO arrow_load SETTINGS input_format_arrow_case_insensitive_column_matching=true FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_load"
${DATASTORE_CLIENT} --query="drop table arrow_load"
