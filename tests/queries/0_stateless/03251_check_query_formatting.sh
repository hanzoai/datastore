#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_FORMAT --query "CHECK TABLE test PART 'Hello'"
$DATASTORE_FORMAT --query "CHECK TABLE test PARTITION 'Hello'"
$DATASTORE_FORMAT --query "CHECK TABLE test PARTITION tuple()"
$DATASTORE_FORMAT --query "CHECK TABLE test PARTITION ()"
$DATASTORE_FORMAT --query "CHECK TABLE test PARTITION (1, 'Hello', ['World'])"
$DATASTORE_FORMAT --query "CHECK TABLE test PARTITION ALL"
