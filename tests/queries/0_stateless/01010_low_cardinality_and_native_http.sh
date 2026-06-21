#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT --query="drop table if exists tab_str";
$DATASTORE_CLIENT --query="drop table if exists tab_str_lc";

$DATASTORE_CLIENT --query="create table tab_str (x String) engine = MergeTree order by tuple()";
$DATASTORE_CLIENT --query="create table tab_str_lc (x LowCardinality(String)) engine = MergeTree order by tuple()";
$DATASTORE_CLIENT --query="insert into tab_str values ('abc')";

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=select+x+from+tab_str+format+Native" | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+tab_str_lc+FORMAT+Native" --data-binary @-

$DATASTORE_CLIENT --query="select x from tab_str_lc";

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=select+x+from+tab_str_lc+format+Native" | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+tab_str+FORMAT+Native" --data-binary @-

$DATASTORE_CLIENT --query="select '----'";
$DATASTORE_CLIENT --query="select x from tab_str";

$DATASTORE_CLIENT -q "DROP TABLE tab_str"
$DATASTORE_CLIENT -q "DROP TABLE tab_str_lc"
