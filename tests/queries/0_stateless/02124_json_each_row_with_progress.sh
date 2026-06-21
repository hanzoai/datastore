#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS ${DATASTORE_URL} -d "drop table if exists test_progress"
${DATASTORE_CURL} -sS ${DATASTORE_URL} -d "create table test_progress (x UInt64, y UInt64, d Date, a Array(UInt64), s String) engine=MergeTree() order by x"
${DATASTORE_CURL} -sS ${DATASTORE_URL} -d "insert into test_progress select number as x, number + 1 as y, toDate(number) as d, range(number % 10) as a, repeat(toString(number), 10) as s from numbers(200000)"
${DATASTORE_CURL} -sS ${DATASTORE_URL} -d "SELECT * from test_progress FORMAT JSONEachRowWithProgress" | grep -v --text "progress" | grep -v --text "rows_before_limit_at_least" | wc -l
${DATASTORE_CURL} -sS ${DATASTORE_URL} -d "drop table test_progress";
