#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

function cleanup()
{
    rm ${USER_FILES_PATH}/${DATASTORE_DATABASE}_test_02167.*
}
trap cleanup EXIT

for format in TSV TabSeparated TSVWithNames TSVWithNamesAndTypes CSV Parquet ORC Arrow JSONEachRow JSONCompactEachRow CustomSeparatedWithNamesAndTypes
do
    $DATASTORE_CLIENT -q "insert into table function file('${DATASTORE_DATABASE}_test_02167.$format', 'auto', 'x UInt64') select * from numbers(2)"
    $DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.$format')"
    $DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.$format', '$format')"
done

$DATASTORE_CLIENT -q "insert into table function file('${DATASTORE_DATABASE}_test_02167.bin', 'auto', 'x UInt64') select * from numbers(2)"
$DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.bin', 'auto', 'x UInt64')"
$DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.bin', 'RowBinary', 'x UInt64')"

$DATASTORE_CLIENT -q "insert into table function file('${DATASTORE_DATABASE}_test_02167.ndjson', 'auto', 'x UInt64') select * from numbers(2)"
$DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.ndjson')"
$DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.ndjson', 'JSONEachRow', 'x UInt64')"

$DATASTORE_CLIENT -q "insert into table function file('${DATASTORE_DATABASE}_test_02167.messagepack', 'auto', 'x UInt64') select * from numbers(2)"
$DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.messagepack') settings input_format_msgpack_number_of_columns=1"
$DATASTORE_CLIENT -q "select * from file('${DATASTORE_DATABASE}_test_02167.messagepack', 'MsgPack', 'x UInt64')"

