#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

file_name=${DATASTORE_TEST_UNIQUE_NAME}
file_name_1=${file_name}_1
file_name_2=${file_name}_2
file_name_3=${file_name}_3

#################
echo "Test 1: Check that you can specify options with a dashes, not an underscores"

[[ -e $file_name_1 ]] && rm $file_name_1
[[ -e $file_name_2 ]] && rm $file_name_2
[[ -e $file_name_3 ]] && rm $file_name_3

echo "Test 1.1: Check option from config - server_logs_file"

$DATASTORE_LOCAL --log-level=debug --server-logs-file=$file_name_1 -q "SELECT 1;" 2> /dev/null
[[ -e $file_name_1 ]] && echo OK
$DATASTORE_LOCAL --log-level=debug --server-logs-file $file_name_2 -q "SELECT 1;" 2> /dev/null
[[ -e $file_name_2 ]] && echo OK
$DATASTORE_LOCAL --log-level=debug --server_logs_file $file_name_3 -q "SELECT 1;" 2> /dev/null
[[ -e $file_name_3 ]] && echo OK

echo "Test 1.2: Check some option from Settings.h - allow_deprecated_syntax_for_merge_tree"

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test";
$DATASTORE_CLIENT --allow-deprecated-syntax-for-merge-tree=1 --query="CREATE TABLE test (d Date, s String) ENGINE = MergeTree(d, s, 8192)";
$DATASTORE_CLIENT --query="DROP TABLE test";
echo $?

#################
echo "Test 2: check that unicode dashes are handled correctly"

echo "Test 2.1: check em-dash support"
# Unicode code: U+2014
$DATASTORE_LOCAL —query "SELECT 1";

echo "Test 2.2: check en-dash support"
# Unicode code: U+2013
$DATASTORE_LOCAL –query "SELECT 1";

echo "Test 2.3 check mathematical minus support"
# Unicode code: U+2212
$DATASTORE_LOCAL −query "SELECT 1";

rm $file_name_1
rm $file_name_2
rm $file_name_3
