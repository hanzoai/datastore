#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "DROP TABLE IF EXISTS test_table;" | ${DATASTORE_CLIENT}
echo "DROP TABLE IF EXISTS test_table_2;" | ${DATASTORE_CLIENT}
echo "SELECT 1;" | ${DATASTORE_CLIENT}
# Check JSONStringsEachRow Output
echo "CREATE TABLE test_table (value UInt8, name String) ENGINE = MergeTree() ORDER BY value;" | ${DATASTORE_CLIENT}
echo "INSERT INTO test_table VALUES (1, 'a'), (2, 'b'), (3, 'c');" | ${DATASTORE_CLIENT}
echo "SELECT * FROM test_table FORMAT JSONStringsEachRow;" | ${DATASTORE_CLIENT}
echo "SELECT 2;" | ${DATASTORE_CLIENT}
# Check Totals
echo "SELECT name, count() AS c FROM test_table GROUP BY name WITH TOTALS ORDER BY name FORMAT JSONStringsEachRow;" | ${DATASTORE_CLIENT}
echo "SELECT 3;" | ${DATASTORE_CLIENT}
# Check JSONStringsEachRowWithProgress Output
echo "SELECT 1 as a FROM system.one FORMAT JSONStringsEachRowWithProgress;" | ${DATASTORE_CLIENT} | grep -v progress
echo "SELECT 4;" | ${DATASTORE_CLIENT}
# Check Totals
echo "SELECT 1 as a FROM system.one GROUP BY a WITH TOTALS ORDER BY a FORMAT JSONStringsEachRowWithProgress;" | ${DATASTORE_CLIENT} | grep -v progress
echo "DROP TABLE IF EXISTS test_table;" | ${DATASTORE_CLIENT}
echo "SELECT 5;" | ${DATASTORE_CLIENT}
# Check JSONStringsEachRow Input
echo "CREATE TABLE test_table (v1 String, v2 UInt8, v3 DEFAULT v2 * 16, v4 UInt8 DEFAULT 8) ENGINE = MergeTree() ORDER BY v2;" | ${DATASTORE_CLIENT}
echo 'INSERT INTO test_table FORMAT JSONStringsEachRow {"v1": "first", "v2": "1", "v3": "2", "v4": "NULL"} {"v1": "second", "v2": "2", "v3": "null", "v4": "6"};' | ${DATASTORE_CLIENT} --input_format_null_as_default=1
echo "SELECT * FROM test_table FORMAT JSONStringsEachRow;" | ${DATASTORE_CLIENT}
echo "TRUNCATE TABLE test_table;" | ${DATASTORE_CLIENT}
echo "SELECT 6;" | ${DATASTORE_CLIENT}
# Check input_format_null_as_default = 1
echo 'INSERT INTO test_table FORMAT JSONStringsEachRow {"v1": "first", "v2": "1", "v3": "2", "v4": "ᴺᵁᴸᴸ"} {"v1": "second", "v2": "2", "v3": "null", "v4": "6"};' | ${DATASTORE_CLIENT} --input_format_null_as_default=1
echo "SELECT * FROM test_table FORMAT JSONStringsEachRow;" | ${DATASTORE_CLIENT}
echo "TRUNCATE TABLE test_table;" | ${DATASTORE_CLIENT}
echo "SELECT 7;" | ${DATASTORE_CLIENT}
# Check Nested
echo "CREATE TABLE test_table_2 (v1 UInt8, n Nested(id UInt8, name String)) ENGINE = MergeTree() ORDER BY v1;" | ${DATASTORE_CLIENT}
cat << END | ${DATASTORE_CLIENT}
INSERT INTO test_table_2 FORMAT JSONStringsEachRow {"v1": "16", "n.id": "[15, 16, 17]", "n.name": "['first', 'second', 'third']"};
END
echo "SELECT * FROM test_table_2 FORMAT JSONStringsEachRow;" | ${DATASTORE_CLIENT}
echo "TRUNCATE TABLE test_table_2;" | ${DATASTORE_CLIENT}

echo "DROP TABLE IF EXISTS test_table;" | ${DATASTORE_CLIENT}
echo "DROP TABLE IF EXISTS test_table_2;" | ${DATASTORE_CLIENT}
