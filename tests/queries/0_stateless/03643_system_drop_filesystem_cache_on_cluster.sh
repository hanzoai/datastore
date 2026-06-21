#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel, no-object-storage, no-random-settings

# set -x

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


disk_name="${DATASTORE_TEST_UNIQUE_NAME}"
$DATASTORE_CLIENT -m --query """
DROP TABLE IF EXISTS test;
CREATE TABLE test (a Int32, b String)
ENGINE = MergeTree() ORDER BY tuple()
SETTINGS disk = disk(name = '$disk_name', type = cache, max_size = '100Ki', path = ${DATASTORE_TEST_UNIQUE_NAME}, disk = s3_disk);

INSERT INTO test SELECT 1, 'test';
"""

$DATASTORE_CLIENT --query """
SYSTEM SYNC FILESYSTEM CACHE '$disk_name' ON CLUSTER 'test_shard_localhost';
"""

$DATASTORE_CLIENT --query """
SYSTEM CLEAR FILESYSTEM CACHE '$disk_name' ON CLUSTER 'test_shard_localhost';
"""

$DATASTORE_CLIENT --query """
DROP TABLE IF EXISTS test;
"""
