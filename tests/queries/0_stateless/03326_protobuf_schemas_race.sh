#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CURDIR"/../shell_config.sh

DATASTORE_CLIENT="${DATASTORE_CLIENT} --optimize_trivial_insert_select=0"

mkdir -p "${DATASTORE_SCHEMA_FILES}"
mkdir -p "${DATASTORE_SCHEMA_FILES}/${DATASTORE_TEST_UNIQUE_NAME}"
SOURCE_SCHEMA_FILE="${CURDIR}/format_schemas/03234_proto_simple_nested_repeated_noexception.proto"
TARGET_SCHEMA_FILE="${DATASTORE_SCHEMA_FILES}/${DATASTORE_TEST_UNIQUE_NAME}/03234_proto_simple_nested_repeated_noexception.proto"
cp "${SOURCE_SCHEMA_FILE}" "${TARGET_SCHEMA_FILE}"

echo "DROP TABLE IF EXISTS table_file;
CREATE TABLE table_file (
    u     UInt32,
    \`v.w\`   Array(UInt32),
    \`v.x\`   Array(UInt32),
    \`v.y\`   Array(Array(UInt32)),
    \`v.z\`   Array(Array(UInt32))
) ENGINE File(Protobuf) SETTINGS format_schema = '$DATASTORE_TEST_UNIQUE_NAME/03234_proto_simple_nested_repeated_noexception.proto:M';
INSERT INTO table_file SELECT * FROM generateRandom() limit 1000000;
DROP TABLE table_file;" | $DATASTORE_CLIENT -m &

for i in $(seq 1 100)
do
    $DATASTORE_CLIENT -q "SYSTEM CLEAR FORMAT SCHEMA CACHE"
done

rm -rf "${DATASTORE_SCHEMA_FILES}/${DATASTORE_TEST_UNIQUE_NAME}"
