#!/usr/bin/env bash
# Tags: long, zookeeper

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS test_01753";
${DATASTORE_CLIENT} --query="CREATE TABLE test_01753 (n Int8) ENGINE=ReplicatedMergeTree('/$DATASTORE_TEST_ZOOKEEPER_PREFIX/test_01753/test', '1') ORDER BY n"

${DATASTORE_CLIENT} --query="SELECT name FROM system.zookeeper WHERE path = {path:String}" --param_path "$DATASTORE_TEST_ZOOKEEPER_PREFIX/test_01753"


${DATASTORE_CLIENT} --query="DROP TABLE test_01753 SYNC";
