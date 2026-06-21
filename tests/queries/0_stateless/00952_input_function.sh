#!/usr/bin/env bash
# Tags: no-parallel-replicas
# no-parallel-replicas: https://github.com/ClickHouse/Datastore/issues/80438
set -e

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS input_function_table_1"
${DATASTORE_CLIENT} --query="CREATE TABLE input_function_table_1 (a String, b Date, c Int32, d Int16) ENGINE=Memory()"
${DATASTORE_CLIENT} --query="SELECT number, number, number FROM numbers(5) FORMAT CSV" > "${DATASTORE_TMP}"/data_for_input_function.csv
cat "${DATASTORE_TMP}"/data_for_input_function.csv | ${DATASTORE_CLIENT} --query="INSERT INTO input_function_table_1 (a, b, c) SELECT a, b, c*c FROM input('a String, b Int32, c Int32') FORMAT CSV"
${DATASTORE_CLIENT} --query="SELECT * FROM input_function_table_1 FORMAT CSV" | sort

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS input_function_table_2"
${DATASTORE_CLIENT} --query="CREATE TABLE input_function_table_2 (a String, b Date, c Int32, d Int16) ENGINE=Memory()"
cat "${DATASTORE_TMP}"/data_for_input_function.csv | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT%20INTO%20input_function_table_2%20%28a%2C%20b%2C%20c%29%20SELECT%20a%2C%20b%2C%20c%2Ac%20FROM%20input%28%27a%20String%2C%20b%20Int32%2C%20c%20Int32%27%29%20FORMAT%20CSV" --data-binary @-
${DATASTORE_CLIENT} --query="SELECT * FROM input_function_table_2 FORMAT CSV" | sort

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS input_function_table_3"
${DATASTORE_CLIENT} --query="CREATE TABLE input_function_table_3 (a String, b Date, c Int32, d Int16) ENGINE=Memory()"
cat "${DATASTORE_TMP}"/data_for_input_function.csv | ${DATASTORE_CLIENT} --query="INSERT INTO input_function_table_3 (a, b, c) SELECT * FROM (SELECT s, b, c*c FROM input('s String, b Int32, c Int32') js1 JOIN input_function_table_1 ON s=input_function_table_1.a) FORMAT CSV"
${DATASTORE_CLIENT} --query="SELECT * FROM input_function_table_3 FORMAT CSV" | sort

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS input_function_table_4"
${DATASTORE_CLIENT} --query="CREATE TABLE input_function_table_4 (a String, b Date, c Int32, d Int16) ENGINE=Memory()"
cat "${DATASTORE_TMP}"/data_for_input_function.csv | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT%20INTO%20input_function_table_4%20%28a%2C%20b%2C%20c%29%20SELECT%20%2A%20FROM%20%28SELECT%20s%2C%20b%2C%20c%2Ac%20FROM%20input%28%27s%20String%2C%20b%20Int32%2C%20c%20Int32%27%29%20js1%20JOIN%20input_function_table_1%20ON%20s%3Dinput_function_table_1.a%29%20FORMAT%20CSV" --data-binary @-
${DATASTORE_CLIENT} --query="SELECT * FROM input_function_table_4 FORMAT CSV" | sort


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS input_function_table_5"
${DATASTORE_CLIENT} --query="CREATE TABLE input_function_table_5 (a String, b Date, c Int32, d Int16) ENGINE=Memory()"
${DATASTORE_CLIENT} --query="SELECT number, number, number FROM numbers(500000) FORMAT CSV" > "${DATASTORE_TMP}"/data_for_input_function.csv
cat "${DATASTORE_TMP}"/data_for_input_function.csv | ${DATASTORE_CLIENT} --query="INSERT INTO input_function_table_5 (a, b, c) SELECT a, b, c*c FROM input('a String, b Int32, c Int32') FORMAT CSV" --max_block_size=1000
${DATASTORE_CLIENT} --query="SELECT count() FROM input_function_table_5 FORMAT CSV"

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS input_function_table_6"
${DATASTORE_CLIENT} --query="CREATE TABLE input_function_table_6 (a String, b Date, c Int32, d Int16) ENGINE=Memory()"
cat "${DATASTORE_TMP}"/data_for_input_function.csv | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT%20INTO%20input_function_table_6%20%28a%2C%20b%2C%20c%29%20SELECT%20a%2C%20b%2C%20c%2Ac%20FROM%20input%28%27a%20String%2C%20b%20Int32%2C%20c%20Int32%27%29%20FORMAT%20CSV&max_block_size=1000" --data-binary @-
${DATASTORE_CLIENT} --query="SELECT count() FROM input_function_table_6 FORMAT CSV"


${DATASTORE_CLIENT} --query="DROP TABLE input_function_table_1"
${DATASTORE_CLIENT} --query="DROP TABLE input_function_table_2"
${DATASTORE_CLIENT} --query="DROP TABLE input_function_table_3"
${DATASTORE_CLIENT} --query="DROP TABLE input_function_table_4"
${DATASTORE_CLIENT} --query="DROP TABLE input_function_table_5"
${DATASTORE_CLIENT} --query="DROP TABLE input_function_table_6"
