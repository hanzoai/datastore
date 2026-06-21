#!/usr/bin/env bash
# Tags: no-fasttest

# set -x

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


$DATASTORE_CLIENT -m --query """
DROP TABLE IF EXISTS test;
CREATE TABLE test (a Int32, b String)
ENGINE = MergeTree() ORDER BY tuple()
SETTINGS disk = disk(name = 's3_disk', type = cache, max_size = '100Ki', path = ${DATASTORE_TEST_UNIQUE_NAME}, disk = s3_disk);
""" 2>&1 | grep -q "Disk \`s3_disk\` already exists and is described by the config" && echo 'OK' || echo 'FAIL'

disk_name="${DATASTORE_TEST_UNIQUE_NAME}"

$DATASTORE_CLIENT -m --query """
SELECT count() FROM system.disks WHERE name = '$disk_name'
"""

$DATASTORE_CLIENT -m --query """
DROP TABLE IF EXISTS test;
CREATE TABLE test (a Int32, b String)
ENGINE = MergeTree() ORDER BY tuple()
SETTINGS disk = disk(name = '$disk_name', type = cache, max_size = '100Ki', path = ${DATASTORE_TEST_UNIQUE_NAME}, disk = s3_disk);
"""

$DATASTORE_CLIENT -m --query """
SELECT count() FROM system.disks WHERE name = '$disk_name'
"""
