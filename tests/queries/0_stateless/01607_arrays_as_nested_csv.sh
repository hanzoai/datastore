#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "
DROP TABLE IF EXISTS test;
CREATE TABLE test (a Array(String)) ENGINE = Memory;
"

${DATASTORE_CLIENT} --query "INSERT INTO test FORMAT CSV" <<END
"['Hello', 'world', '42"" TV']"
END

${DATASTORE_CLIENT} --format_csv_allow_single_quotes 0 --query "INSERT INTO test FORMAT CSV" <<END
"'Hello', 'world', '42"" TV'"
END

${DATASTORE_CLIENT} --input_format_csv_arrays_as_nested_csv 1 --query "INSERT INTO test FORMAT CSV" <<END
"[""Hello"", ""world"", ""42"""" TV""]"
"""Hello"", ""world"", ""42"""" TV"""
END

${DATASTORE_CLIENT} --query "
SELECT * FROM test;
DROP TABLE IF EXISTS test;
"
