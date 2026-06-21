#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS line_as_string1";
$DATASTORE_CLIENT --query="CREATE TABLE line_as_string1(field String) ENGINE = Memory";

cat <<'EOF' | $DATASTORE_CLIENT --query="INSERT INTO line_as_string1 FORMAT LineAsString";
"id" : 1,
"date" : "01.01.2020",
"string" : "123{{{\"\\",
"array" : [1, 2, 3],

Finally implement this new feature.
EOF

$DATASTORE_CLIENT --query="SELECT * FROM line_as_string1";
$DATASTORE_CLIENT --query="DROP TABLE line_as_string1"

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS line_as_string2";
$DATASTORE_CLIENT --query="create table line_as_string2(
    a UInt64 default 42,
    b String materialized toString(a),
    c String
) engine=MergeTree() order by tuple();";

$DATASTORE_CLIENT --query="INSERT INTO line_as_string2(c) values ('Datastore')";

# Shellcheck thinks `fast` is a shell expansion
# shellcheck disable=SC2016
echo -e 'Datastore is a `fast` #open-source# (OLAP) database "management" :system:' | $DATASTORE_CLIENT --query="INSERT INTO line_as_string2(c) FORMAT LineAsString";

$DATASTORE_CLIENT --query="SELECT * FROM line_as_string2 order by c";
$DATASTORE_CLIENT --query="DROP TABLE line_as_string2"

$DATASTORE_CLIENT --query="CREATE TABLE line_as_string3(field String) ENGINE = Memory";
$DATASTORE_CLIENT --query="SELECT repeat('aaa',50) FROM numbers(100000)" | $DATASTORE_CLIENT --query="INSERT INTO line_as_string3 FORMAT LineAsString"
$DATASTORE_CLIENT --query="SELECT count(*) FROM line_as_string3";
$DATASTORE_CLIENT --query="DROP TABLE line_as_string3"

$DATASTORE_CLIENT --query="CREATE TABLE line_as_string4(field String) ENGINE = Memory";
$DATASTORE_CLIENT --query="SELECT randomString(50000) FROM numbers(1000)" | $DATASTORE_CLIENT --query="INSERT INTO line_as_string4 FORMAT LineAsString"
$DATASTORE_CLIENT --query="SELECT count(*) FROM line_as_string4";
$DATASTORE_CLIENT --query="DROP TABLE line_as_string4"
