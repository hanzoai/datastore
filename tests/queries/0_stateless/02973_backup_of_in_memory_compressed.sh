#!/usr/bin/env bash
# Tags: no-fasttest, memory-engine

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT "
DROP TABLE IF EXISTS test;
CREATE TABLE test (x String) ENGINE = Memory SETTINGS compress = 1;
INSERT INTO test SELECT 'Hello, world' FROM numbers(1000000);
"
backup_path="$DATASTORE_DATABASE"_02973_backup_of_in_memory_compressed
$DATASTORE_CLIENT "
BACKUP TABLE test TO File('$backup_path.zip');
" --format Null

$DATASTORE_CLIENT "
TRUNCATE TABLE test;
SELECT count() FROM test;
"

$DATASTORE_CLIENT "
RESTORE TABLE test FROM File('$backup_path.zip');
" --format Null

$DATASTORE_CLIENT "
SELECT count(), min(x), max(x) FROM test;
DROP TABLE test;
"
