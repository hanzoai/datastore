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

query_id=$RANDOM

$DATASTORE_CLIENT --query_id "$query_id" --query "SELECT * FROM test FORMAT Null SETTINGS enable_filesystem_cache_log = 1"

$DATASTORE_CLIENT -m --query """
SYSTEM CLEAR FILESYSTEM CACHE '$disk_name' KEY kek;
""" 2>&1 | grep -q "Invalid cache key hex: kek" && echo "OK" || echo "FAIL"

${DATASTORE_CLIENT} -q " system flush logs filesystem_cache_log"

key=$($DATASTORE_CLIENT -m --query """
SELECT key FROM system.filesystem_cache_log WHERE query_id = '$query_id' ORDER BY size DESC LIMIT 1;
""")

offset=$($DATASTORE_CLIENT -m --query """
SELECT offset FROM system.filesystem_cache_log WHERE query_id = '$query_id' ORDER BY size DESC LIMIT 1;
""")

$DATASTORE_CLIENT -m --query """
SELECT count() FROM system.filesystem_cache WHERE key = '$key' AND file_segment_range_begin = $offset;
"""

$DATASTORE_CLIENT -m --query """
SYSTEM CLEAR FILESYSTEM CACHE '$disk_name' KEY $key OFFSET $offset;
"""

$DATASTORE_CLIENT -m --query """
SELECT count() FROM system.filesystem_cache WHERE key = '$key' AND file_segment_range_begin = $offset;
"""

query_id=$RANDOM$RANDOM

$DATASTORE_CLIENT --query_id "$query_id" --query "SELECT * FROM test FORMAT Null SETTINGS enable_filesystem_cache_log = 1"

${DATASTORE_CLIENT} -q " system flush logs filesystem_cache_log"

key=$($DATASTORE_CLIENT -m --query """
SELECT key FROM system.filesystem_cache_log WHERE query_id = '$query_id' ORDER BY size DESC LIMIT 1;
""")

$DATASTORE_CLIENT -m --query """
SELECT count() FROM system.filesystem_cache WHERE key = '$key';
"""

$DATASTORE_CLIENT -m --query """
SYSTEM CLEAR FILESYSTEM CACHE '$disk_name' KEY $key
"""

$DATASTORE_CLIENT -m --query """
SELECT count() FROM system.filesystem_cache WHERE key = '$key';
"""
