#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

ROLE="r_${DATASTORE_TEST_UNIQUE_NAME}"
USER="u_${DATASTORE_TEST_UNIQUE_NAME}"
QUOTA="q_${DATASTORE_TEST_UNIQUE_NAME}"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS written_bytes_02247"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${ROLE}"
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "DROP QUOTA IF EXISTS ${QUOTA}"

${DATASTORE_CLIENT} -q "CREATE TABLE written_bytes_02247(s String) ENGINE = Memory"

${DATASTORE_CLIENT} -q "CREATE ROLE ${ROLE}"
${DATASTORE_CLIENT} -q "CREATE USER ${USER}"
${DATASTORE_CLIENT} -q "GRANT ALL ON *.* TO ${ROLE}"
${DATASTORE_CLIENT} -q "GRANT ${ROLE} to ${USER}"
${DATASTORE_CLIENT} -q "CREATE QUOTA ${QUOTA} FOR INTERVAL 100 YEAR MAX WRITTEN BYTES = 30 TO ${ROLE}"

# The value 'qwqw' means about 13 bytes are to be written, so the current quota (30 bytes) gives the ability to write 'qwqw' 2 times.
${DATASTORE_CLIENT} --user ${USER} --async_insert 1 -q "INSERT INTO written_bytes_02247 VALUES ('qwqw')"
#${DATASTORE_CLIENT} --user ${USER} -q "SHOW CURRENT QUOTA"
${DATASTORE_CLIENT} --user ${USER} --async_insert 0 -q "INSERT INTO written_bytes_02247 VALUES ('qwqw')"
#${DATASTORE_CLIENT} --user ${USER} -q "SHOW CURRENT QUOTA"
${DATASTORE_CLIENT} --user ${USER} --async_insert 1 -q "INSERT INTO written_bytes_02247 VALUES ('qwqw')" 2>&1 | grep -m1 -o QUOTA_EXCEEDED
${DATASTORE_CLIENT} --user ${USER} --async_insert 0 -q "INSERT INTO written_bytes_02247 VALUES ('qwqw')" 2>&1 | grep -m1 -o QUOTA_EXCEEDED

${DATASTORE_CLIENT} -q "SELECT written_bytes > 10 FROM system.quotas_usage WHERE quota_name = '${QUOTA}'"
${DATASTORE_CLIENT} -q "SELECT count() FROM written_bytes_02247"

${DATASTORE_CLIENT} -q "DROP QUOTA ${QUOTA}"
${DATASTORE_CLIENT} -q "CREATE QUOTA ${QUOTA} FOR INTERVAL 100 YEAR MAX WRITTEN BYTES = 1000 TO ${ROLE}"
${DATASTORE_CLIENT} -q "TRUNCATE TABLE written_bytes_02247"

# Numbers from 0 to 50 means about 540 bytes are to be written, so the current quota (1000 bytes) is enough to do so.
${DATASTORE_CLIENT} --user ${USER} -q "INSERT INTO written_bytes_02247 SELECT toString(number) FROM numbers(50)"

# Numbers from 0 to 100 means about 1090 bytes are to be written, so the current quota (1000 bytes total - 540 bytes already used) is NOT enough to do so.
${DATASTORE_CLIENT} --user ${USER} -q "INSERT INTO written_bytes_02247 SELECT toString(number) FROM numbers(100)" 2>&1 | grep -m1 -o QUOTA_EXCEEDED

${DATASTORE_CLIENT} -q "SELECT written_bytes > 100 FROM system.quotas_usage WHERE quota_name = '${QUOTA}'"
${DATASTORE_CLIENT} -q "SELECT count() FROM written_bytes_02247"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS written_bytes_02247"
${DATASTORE_CLIENT} -q "DROP ROLE IF EXISTS ${ROLE}"
${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
${DATASTORE_CLIENT} -q "DROP QUOTA IF EXISTS ${QUOTA}"
