#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "drop table if exists dict_src;"
$DATASTORE_CLIENT -q "drop dictionary if exists dict1;"
$DATASTORE_CLIENT -q "drop dictionary if exists dict2;"
$DATASTORE_CLIENT -q "drop table if exists join;"
$DATASTORE_CLIENT -q "drop table if exists t;"

$DATASTORE_CLIENT -q "create table dict_src (n int, m int, s String) engine=MergeTree order by n;"

$DATASTORE_CLIENT -q "create dictionary dict1 (n int default 0, m int default 1, s String default 'qqq')
PRIMARY KEY n
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'dict_src' PASSWORD '' DB '$DATASTORE_DATABASE'))
LIFETIME(MIN 1 MAX 10) LAYOUT(FLAT());"

$DATASTORE_CLIENT -q "create table join(n int, m int default dictGet('$DATASTORE_DATABASE.dict1', 'm', 42::UInt64)) engine=Join(any, left, n);"

$DATASTORE_CLIENT -q "create dictionary dict2 (n int default 0, m int DEFAULT 2)
PRIMARY KEY n
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'join' PASSWORD '' DB '$DATASTORE_DATABASE'))
LIFETIME(MIN 1 MAX 10) LAYOUT(FLAT());"

$DATASTORE_CLIENT -q "create table s (x default joinGet($DATASTORE_DATABASE.join, 'm', 42::int)) engine=Set"

$DATASTORE_CLIENT -q "create table t (n int, m int default joinGet($DATASTORE_DATABASE.join, 'm', 42::int),
s String default dictGet($DATASTORE_DATABASE.dict1, 's', 42::UInt64), y default dictGet($DATASTORE_DATABASE.dict2, 'm', 42::UInt64)) engine=MergeTree order by n;"

$DATASTORE_CLIENT -q "select table, arraySort(dependencies_table),
arraySort(loading_dependencies_table), arraySort(loading_dependent_table) from system.tables where database=currentDatabase() order by table"
$DATASTORE_CLIENT -q "select '====='"
$DATASTORE_CLIENT -q "alter table t add column x int default in(1, $DATASTORE_DATABASE.s), drop column y"

$DATASTORE_CLIENT -q "create materialized view mv to s as select n as x from t where n in (select n from join)"

$DATASTORE_CLIENT -q "select table, arraySort(dependencies_table),
arraySort(loading_dependencies_table), arraySort(loading_dependent_table) from system.tables where database=currentDatabase() order by table"

DATASTORE_CLIENT_DEFAULT_DB=$(echo ${DATASTORE_CLIENT} | sed 's/'"--database=${DATASTORE_DATABASE}"'/--database=default/g')

for _ in {1..10}; do
  $DATASTORE_CLIENT_DEFAULT_DB -q "detach database $DATASTORE_DATABASE;"
  $DATASTORE_CLIENT_DEFAULT_DB -q "attach database $DATASTORE_DATABASE;"
done
$DATASTORE_CLIENT -q "show tables from $DATASTORE_DATABASE;"

$DATASTORE_CLIENT -q "rename table join to join1" 2>&1| grep -Fa "some tables depend on it" >/dev/null && echo "OK"

$DATASTORE_CLIENT -q "drop table join" 2>&1| grep -Fa "some tables depend on it" >/dev/null && echo "OK"
$DATASTORE_CLIENT -q "detach dictionary dict1 permanently" 2>&1| grep -Fa "some tables depend on it" >/dev/null && echo "OK"

$DATASTORE_CLIENT -q "select table, arraySort(dependencies_table),
arraySort(loading_dependencies_table), arraySort(loading_dependent_table) from system.tables where database=currentDatabase() order by table"

engine=`$DATASTORE_CLIENT -q "select engine from system.databases where name='${DATASTORE_DATABASE}'"`
$DATASTORE_CLIENT -q "drop database if exists ${DATASTORE_DATABASE}_1"
if [[ $engine == "Atomic" ]]; then
    $DATASTORE_CLIENT -q "rename database ${DATASTORE_DATABASE} to ${DATASTORE_DATABASE}_1" 2>&1| grep -Fa "some tables depend on it" >/dev/null && echo "OK"
else
    echo "OK"
fi

$DATASTORE_CLIENT -q "rename table t to ${DATASTORE_DATABASE}_2.t" |& grep -m1 -F -o UNKNOWN_DATABASE
$DATASTORE_CLIENT -q "select table, arraySort(dependencies_table),
arraySort(loading_dependencies_table), arraySort(loading_dependent_table) from system.tables where database in (currentDatabase(), '$t_database') order by table"

$DATASTORE_CLIENT -q "drop table mv"
$DATASTORE_CLIENT -q "create database ${DATASTORE_DATABASE}_1"

t_database=${DATASTORE_DATABASE}

if [[ $engine == "Atomic" ]]; then
    $DATASTORE_CLIENT -q "rename table t to ${DATASTORE_DATABASE}_1.t"
    $DATASTORE_CLIENT -q "rename database ${DATASTORE_DATABASE}_1 to ${DATASTORE_DATABASE}_1_renamed"
    t_database="${DATASTORE_DATABASE}_1_renamed"
fi

$DATASTORE_CLIENT -q "select table, arraySort(dependencies_table),
arraySort(loading_dependencies_table), arraySort(loading_dependent_table) from system.tables where database in (currentDatabase(), '$t_database') order by table"

$DATASTORE_CLIENT -q "drop table ${t_database}.t;"
$DATASTORE_CLIENT -q "drop table s;"
$DATASTORE_CLIENT -q "drop dictionary dict2;"

$DATASTORE_CLIENT -q "select '====='"
$DATASTORE_CLIENT -q "select table, arraySort(dependencies_table),
arraySort(loading_dependencies_table), arraySort(loading_dependent_table) from system.tables where database=currentDatabase() order by table"
if [[ $engine != "Ordinary" ]]; then
    $DATASTORE_CLIENT -q "create or replace table dict_src (n int, m int, s String) engine=MergeTree order by (n, m);"
fi

$DATASTORE_CLIENT -q "drop table join;"
$DATASTORE_CLIENT -q "drop dictionary dict1;"
$DATASTORE_CLIENT -q "drop table dict_src;"
if [[ $t_database != "$DATASTORE_DATABASE" ]]; then
    $DATASTORE_CLIENT -q "drop database if exists ${t_database}"
fi

$DATASTORE_CLIENT -q "drop database if exists ${DATASTORE_DATABASE}_1"
$DATASTORE_CLIENT -q "create database ${DATASTORE_DATABASE}_1"
$DATASTORE_CLIENT -q "create table ${DATASTORE_DATABASE}_1.xdict_src (n int, m int, s String) engine=MergeTree order by n;"
$DATASTORE_CLIENT -q "create dictionary ${DATASTORE_DATABASE}_1.ydict1 (n int default 0, m int default 1, s String default 'qqq')
PRIMARY KEY n
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'xdict_src' PASSWORD '' DB '${DATASTORE_DATABASE}_1'))
LIFETIME(MIN 1 MAX 10) LAYOUT(FLAT());"

$DATASTORE_CLIENT -q "create table ${DATASTORE_DATABASE}_1.zjoin(n int, m int default dictGet('${DATASTORE_DATABASE}_1.ydict1', 'm', 42::UInt64)) engine=Join(any, left, n);"
$DATASTORE_CLIENT -q "drop database ${DATASTORE_DATABASE}_1"
