#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test_02100"
$DATASTORE_CLIENT -q "CREATE TABLE test_02100 (x LowCardinality(Nullable(String)) DEFAULT 'default') ENGINE=Memory()"

FORMATS=('CSV' 'TSV' 'TSVRaw' 'TSKV' 'JSONCompactEachRow' 'JSONEachRow' 'Values')

for format in "${FORMATS[@]}"
do
    echo $format
    $DATASTORE_CLIENT -q "SELECT NULL as x FORMAT $format" | $DATASTORE_CLIENT -q "INSERT INTO test_02100 FORMAT $format"

    $DATASTORE_CLIENT -q "SELECT * FROM test_02100"

    $DATASTORE_CLIENT -q "TRUNCATE TABLE test_02100"
done

$DATASTORE_CLIENT -q "DROP TABLE test_02100"

