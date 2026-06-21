#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

QUERY="ALTER TABLE t22 (DELETE WHERE ('叫' = c1) OR ((792.3673220441809 = c0) AND (c0 = c1))), (MODIFY SETTING persistent = 1), (UPDATE  c1 = 'would' WHERE NOT f2()), (MODIFY SETTING persistent = 0);"

$DATASTORE_FORMAT --query "${QUERY}"