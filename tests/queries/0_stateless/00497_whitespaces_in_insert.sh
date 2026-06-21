#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS ws";
$DATASTORE_CLIENT -q "CREATE TABLE ws (i UInt8) ENGINE = Memory";

$DATASTORE_CLIENT -q "INSERT INTO ws FORMAT RowBinary ;";
$DATASTORE_CLIENT -q "INSERT INTO ws FORMAT RowBinary 	; ";
$DATASTORE_CLIENT -q "INSERT INTO ws FORMAT RowBinary
; ";
echo -n ";" | $DATASTORE_CLIENT -q "INSERT INTO ws FORMAT RowBinary";

$DATASTORE_CLIENT --max_threads=1 -q "SELECT * FROM ws ORDER BY ALL";
$DATASTORE_CLIENT -q "DROP TABLE ws";


$DATASTORE_CLIENT -q "SELECT ''";


$DATASTORE_CLIENT -q "CREATE TABLE ws (s String) ENGINE = Memory";
$DATASTORE_CLIENT -q "INSERT INTO ws FORMAT TSV	;
";
echo ";" | $DATASTORE_CLIENT -q "INSERT INTO ws FORMAT TSV"
if $DATASTORE_CLIENT -q "INSERT INTO ws FORMAT TSV;" 1>/dev/null 2>/dev/null; then
    echo ERROR;
fi
$DATASTORE_CLIENT --max_threads=1 -q "SELECT * FROM ws ORDER BY ALL";

$DATASTORE_CLIENT -q "DROP TABLE ws";
