#!/usr/bin/env bash
# Tags: no-fasttest
# Tag no-fasttest: depends on brotli and bzip2

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

for m in gz br xz zst bz2 
do
    ${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS file"
    ${DATASTORE_CLIENT} --query "CREATE TABLE file (x UInt64) ENGINE = File(Native, '${DATASTORE_DATABASE}/${m}.data.${m}')"
    ${DATASTORE_CLIENT} --query "TRUNCATE TABLE file"
    ${DATASTORE_CLIENT} --query "INSERT INTO file SELECT * FROM numbers(100000)"
    ${DATASTORE_CLIENT} --query "SELECT count(), max(x) FROM file"
    ${DATASTORE_CLIENT} --query "DROP TABLE file"
done

