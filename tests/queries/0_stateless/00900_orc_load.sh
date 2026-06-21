#!/usr/bin/env bash
# Tags: no-ubsan, no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS orc_load"
${DATASTORE_CLIENT} --query="CREATE TABLE orc_load (int Int32, smallint Int8, bigint Int64, float Float32, double Float64, date Date, y String, datetime64 DateTime64(3)) ENGINE = Memory"
${DATASTORE_CLIENT} --query="insert into orc_load values (0, 0, 0, 0, 0, '2019-01-01', 'test1', toDateTime64('2019-01-01 02:03:04.567', 3)), (2147483647, -1, 9223372036854775806, 123.345345, 345345.3453451212, '2019-01-01', 'test2', toDateTime64('2019-01-01 02:03:04.567', 3))"
${DATASTORE_CLIENT} --query="select * from orc_load FORMAT ORC" > "${DATASTORE_TMP}"/test.orc
${DATASTORE_CLIENT} --query="truncate table orc_load"

cat "${DATASTORE_TMP}"/test.orc | ${DATASTORE_CLIENT} -q "insert into orc_load format ORC"
${DATASTORE_CLIENT} -q "insert into orc_load format ORC" < "${DATASTORE_TMP}"/test.orc
${DATASTORE_CLIENT} --query="select * from orc_load"
${DATASTORE_CLIENT} --query="drop table orc_load"
