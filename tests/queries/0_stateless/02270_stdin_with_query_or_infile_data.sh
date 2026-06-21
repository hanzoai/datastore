#!/usr/bin/env bash
# Tags: no-parallel

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_02270"
$DATASTORE_CLIENT -q "CREATE TABLE test_02270 (x UInt32) ENGINE=Memory"

echo "(42)" | $DATASTORE_CLIENT -q "INSERT INTO test_02270 FORMAT Values (24)"
$DATASTORE_CLIENT -q "SELECT * FROM test_02270 ORDER BY x"

echo "(24)" > 02270_data.values
echo "(42)" | $DATASTORE_CLIENT -q "INSERT INTO test_02270 FROM INFILE '02270_data.values'"
$DATASTORE_CLIENT -q "SELECT * FROM test_02270 ORDER BY x"

$DATASTORE_CLIENT -q "DROP TABLE test_02270"
rm 02270_data.values
