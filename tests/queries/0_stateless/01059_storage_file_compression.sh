#!/usr/bin/env bash
# Tags: no-fasttest
# Tag no-fasttest: depends on brotli and bzip2

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

for m in gz br xz zst lz4 bz2
do
    ${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS file"
    ${DATASTORE_CLIENT} --query "CREATE TABLE file (x UInt64) ENGINE = File(TSV, '${DATASTORE_DATABASE}/${m}.tsv.${m}')"
    ${DATASTORE_CLIENT} --query "TRUNCATE TABLE file"
    ${DATASTORE_CLIENT} --query "INSERT INTO file SELECT * FROM numbers(1000000)"
    ${DATASTORE_CLIENT} --query "SELECT count(), max(x) FROM file"
    ${DATASTORE_CLIENT} --query "DROP TABLE file"
done

${DATASTORE_CLIENT} --max_read_buffer_size=1048576 --query "SELECT count(), max(x) FROM file('${DATASTORE_DATABASE}/{gz,br,xz,zst,lz4,bz2}.tsv.{gz,br,xz,zst,lz4,bz2}', TSV, 'x UInt64')"

for m in gz br xz zst lz4 bz2
do
    ${DATASTORE_CLIENT} --max_read_buffer_size=1048576 --query "SELECT count() < 4000000, max(x) FROM file('${DATASTORE_DATABASE}/${m}.tsv.${m}', RowBinary, 'x UInt8', 'none')"
done

