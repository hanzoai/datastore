#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS bug";
$DATASTORE_CLIENT --allow_deprecated_syntax_for_merge_tree=1 --query="CREATE TABLE bug (d Date, s String) ENGINE = MergeTree(d, s, 8192)";
$DATASTORE_CLIENT --query="INSERT INTO bug VALUES ('2019-08-09', 'hello'), ('2019-08-10', 'world'), ('2019-08-11', 'world'), ('2019-08-12', 'hello')";

#SET force_primary_key = 1;

$DATASTORE_CLIENT --query="SELECT * FROM bug WHERE (s, d) IN (SELECT (s, max(d)) FROM bug GROUP BY s) ORDER BY d" 2>&1 | grep "Number of columns in section IN doesn't match" > /dev/null && echo "OK1";
$DATASTORE_CLIENT --query="SELECT * FROM bug WHERE (s, d, s) IN (SELECT s, max(d) FROM bug GROUP BY s)" 2>&1 | grep "Number of columns in section IN doesn't match" > /dev/null && echo "OK2";
$DATASTORE_CLIENT --query="SELECT * FROM bug WHERE (s, d) IN (SELECT s, max(d), s FROM bug GROUP BY s)" 2>&1 | grep "Number of columns in section IN doesn't match" > /dev/null && echo "OK3";

$DATASTORE_CLIENT --query="SELECT * FROM bug WHERE (s, toDateTime(d)) IN (SELECT s, max(d) FROM bug GROUP BY s)" 2>&1 | grep "Types of column 2 in section IN don't match" > /dev/null && echo "OK4";
$DATASTORE_CLIENT --query="SELECT * FROM bug WHERE (s, d) IN (SELECT s, toDateTime(max(d)) FROM bug GROUP BY s)" 2>&1 | grep "Types of column 2 in section IN don't match" > /dev/null && echo "OK5";

$DATASTORE_CLIENT --query="SELECT * FROM bug WHERE (s, d) IN (SELECT s, max(d) FROM bug GROUP BY s) ORDER BY d";

$DATASTORE_CLIENT --query="DROP TABLE bug";
