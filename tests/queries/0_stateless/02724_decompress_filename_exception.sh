#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

FILENAME="${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}"_corrupted_file.tsv.xx

echo 'corrupted file' > $FILENAME;

$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'gzip')" 2>&1    | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'deflate')" 2>&1 | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'br')" 2>&1      | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'xz')" 2>&1      | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'zstd')" 2>&1    | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'lz4')" 2>&1     | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'bz2')" 2>&1     | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';
$DATASTORE_CLIENT --query "SELECT * FROM file('${FILENAME}', 'TSV', 'c UInt32', 'snappy')" 2>&1  | grep -q "While reading from: $FILENAME" && echo 'Ok' || echo 'Fail';

rm $FILENAME;
