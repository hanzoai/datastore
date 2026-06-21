#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_dicts"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_dicts (a LowCardinality(String)) engine=MergeTree order by a"
${DATASTORE_CLIENT} --query="SYSTEM STOP MERGES arrow_dicts"
${DATASTORE_CLIENT} --query="INSERT INTO arrow_dicts select toString(number) from numbers(120);"
${DATASTORE_CLIENT} --query="INSERT INTO arrow_dicts select toString(number) from numbers(120, 120);"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_dicts FORMAT Arrow SETTINGS output_format_arrow_low_cardinality_as_dictionary=1" > "${DATASTORE_TMP}"/$DATASTORE_TEST_UNIQUE_NAME.arrow

${DATASTORE_CLIENT} --query="DROP TABLE arrow_dicts"

$DATASTORE_LOCAL -q "select uniqExact(a) from file('$DATASTORE_TMP/$DATASTORE_TEST_UNIQUE_NAME.arrow')"

$DATASTORE_LOCAL -q "select * from file('$CUR_DIR/data_arrow/different_dicts.arrowstream') order by x"

$DATASTORE_LOCAL -q "select * from file('$CUR_DIR/data_arrow/non_unique_dict.arrowstream') -- { serverError INCORRECT_DATA }"
