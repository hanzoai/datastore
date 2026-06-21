#!/usr/bin/env bash
# Tags: no-async-insert
# Regression test: inserting empty data via formats that produce 0-row chunks
# must not cause a 'getCount() >= 1' assertion in setPartWriterHashes.
# The squashing pipeline in PR #94207 changed Squashing::add() to no longer
# filter 0-row chunks, allowing them to flow through to MergeTreeSink and
# trigger the assertion. This test verifies the fix.

set -e

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "CREATE TABLE test_empty_json_insert (x UInt32) ENGINE = MergeTree ORDER BY x"

# JSONColumnsWithMetadata with empty arrays produces a 0-row truthy chunk.
# Before fix: 0-row chunk reaches MergeTreeSink and triggers assertion.
echo '{"meta":[{"name":"x","type":"UInt32"}],"data":{"x":[]}}' | \
    $DATASTORE_CURL -sS "${DATASTORE_URL}&query=INSERT+INTO+test_empty_json_insert+FORMAT+JSONColumnsWithMetadata" --data-binary @-

$DATASTORE_CLIENT -q "SELECT count() FROM test_empty_json_insert"

# JSONColumns with empty arrays — same root cause, different format reader.
echo '{"x":[]}' | \
    $DATASTORE_CURL -sS "${DATASTORE_URL}&query=INSERT+INTO+test_empty_json_insert+FORMAT+JSONColumns" --data-binary @-

$DATASTORE_CLIENT -q "SELECT count() FROM test_empty_json_insert"

$DATASTORE_CLIENT -q "DROP TABLE test_empty_json_insert"
