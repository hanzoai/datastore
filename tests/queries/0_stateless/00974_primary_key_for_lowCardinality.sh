#!/usr/bin/env bash
# Tags: no-random-merge-tree-settings

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS lowString;"
$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS string;"

$DATASTORE_CLIENT --query="
create table lowString
(
a LowCardinality(String),
b Date
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(b)
ORDER BY (a)"

$DATASTORE_CLIENT --query="
create table string
(
a String,
b Date
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(b)
ORDER BY (a)"

$DATASTORE_CLIENT --query="insert into lowString (a, b) select top 100000 toString(number), today() from system.numbers"

$DATASTORE_CLIENT --query="insert into string (a, b) select top 100000 toString(number), today() from system.numbers"

$DATASTORE_CLIENT --query="select count() from lowString where a in ('1', '2') SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0 FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="select count() from string where a in ('1', '2') SETTINGS merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability = 0.0 FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="DROP TABLE lowString;"
$DATASTORE_CLIENT --query="DROP TABLE string;"
