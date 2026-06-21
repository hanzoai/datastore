#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

declare -a functions=("groupArraySample" "groupUniqArray")
declare -a engines=("Memory" "MergeTree order by n" "Log")

for func in "${functions[@]}"
do
  for engine in "${engines[@]}"
  do
    $DATASTORE_CLIENT -q "drop table if exists t";
    $DATASTORE_CLIENT -q "create table t (n UInt8, a1 AggregateFunction($func(1), UInt8)) engine=$engine"
    $DATASTORE_CLIENT -q "insert into t select number % 5 as n, ${func}State(1)(toUInt8(number)) from numbers(10) group by n"

    $DATASTORE_CLIENT -q "select * from t format TSV" | $DATASTORE_CLIENT -q "insert into t format TSV"
    $DATASTORE_CLIENT -q "select countDistinct(n), countDistinct(a1) from t"

    $DATASTORE_CLIENT -q "drop table t";
  done
done
