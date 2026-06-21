#!/usr/bin/env bash
# Tags: no-replicated-database, zookeeper, no-shared-merge-tree
# no-shared-merge-tree: depend on specific paths created by replicated tables

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS sample_table;"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS sample_table_2;"

${DATASTORE_CLIENT} --query="CREATE TABLE sample_table (
    key UInt64
)
ENGINE ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/02221_system_zookeeper_unrestricted_like', '1')
ORDER BY tuple();
DROP TABLE IF EXISTS sample_table SYNC;"


${DATASTORE_CLIENT} --query "CREATE TABLE sample_table_2 (
    key UInt64
)
ENGINE ReplicatedMergeTree('/datastore/$DATASTORE_TEST_ZOOKEEPER_PREFIX/02221_system_zookeeper_unrestricted_like_2', '1')
ORDER BY tuple();"

${DATASTORE_CLIENT} --allow_unrestricted_reads_from_keeper=1 --query="SELECT name FROM (SELECT path, name FROM system.zookeeper WHERE path LIKE '/datastore%' ORDER BY name) WHERE path LIKE '%$DATASTORE_TEST_ZOOKEEPER_PREFIX/02221_system_zookeeper_unrestricted_like%' AND name NOT LIKE 'zero\\_copy%' AND name != 'shared'"

${DATASTORE_CLIENT} --query="SELECT '-------------------------'"

${DATASTORE_CLIENT} --allow_unrestricted_reads_from_keeper=1 --query="SELECT name FROM (SELECT path, name FROM system.zookeeper WHERE path LIKE '/datastore/%' ORDER BY name) WHERE path LIKE '%$DATASTORE_TEST_ZOOKEEPER_PREFIX/02221_system_zookeeper_unrestricted_like%' AND name NOT LIKE 'zero\\_copy%' AND name != 'shared'"

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS sample_table;"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS sample_table_2;"
