#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "
CREATE TABLE tab
(
    a DateTime,
    pk String
) Engine = MergeTree() ORDER BY pk;
"

# Pin to 'basic' mode: the test asserts on the strict-parser error messages.
DATASTORE_CLIENT_BASIC="${DATASTORE_CLIENT} --cast_string_to_date_time_mode=basic --date_time_input_format=basic"

${DATASTORE_CLIENT_BASIC} --query "SELECT count(*) FROM tab WHERE a = '2024-08-06 09:58:09'"

${DATASTORE_CLIENT_BASIC} --query "SELECT count(*) FROM tab WHERE a = '2024-08-06 09:58:0'" 2>&1 | grep -F -q "Cannot parse time component of DateTime 09:58:0" && echo "OK" || echo "FAIL";

${DATASTORE_CLIENT_BASIC} --query "SELECT count(*) FROM tab WHERE a = '2024-08-0 09:58:09'" 2>&1 | grep -F -q "Cannot convert string '2024-08-0 09:58:09" && echo "OK" || echo "FAIL";
