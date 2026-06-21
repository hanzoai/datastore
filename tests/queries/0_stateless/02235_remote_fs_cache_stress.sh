#!/usr/bin/env bash
# Tags: no-fasttest, long, no-random-settings

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


${DATASTORE_CLIENT} --allow_suspicious_low_cardinality_types=1 --multiline --query="""

DROP TABLE IF EXISTS t_01411;
DROP TABLE IF EXISTS t_01411_num;
drop table if exists lc_dict_reading;

CREATE TABLE t_01411(
    str LowCardinality(String),
    arr Array(LowCardinality(String)) default [str]
) ENGINE = MergeTree()
ORDER BY tuple();

INSERT INTO t_01411 (str) SELECT concat('asdf', toString(number % 10000)) FROM numbers(100000);

CREATE TABLE t_01411_num(
    num UInt8,
    arr Array(LowCardinality(Int64)) default [num]
) ENGINE = MergeTree()
ORDER BY tuple();

INSERT INTO t_01411_num (num) SELECT number % 1000 FROM numbers(100000);

create table lc_dict_reading (val UInt64, str LowCardinality(String), pat String) engine = MergeTree order by val;
insert into lc_dict_reading select number, if(number < 8192 * 4, number % 100, number) as s, s from system.numbers limit 100000;
"""

function go()
{
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "select sum(toUInt64(str)), sum(toUInt64(pat)) from lc_dict_reading where val < 8129 or val > 8192 * 4"

  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE str = 'asdf337'"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE arr[1] = 'asdf337'"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE has(arr, 'asdf337')"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE indexOf(arr, 'asdf337') > 0"

  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE arr[1] = str"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE has(arr, str)"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411 WHERE indexOf(arr, str) > 0"

  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE num = 42"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE arr[1] = 42"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE has(arr, 42)"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE indexOf(arr, 42) > 0"

  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE arr[1] = num"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE has(arr, num)"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE indexOf(arr, num) > 0"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT count() FROM t_01411_num WHERE indexOf(arr, num % 337) > 0"

  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT indexOf(['a', 'b', 'c'], toLowCardinality('a'))"
  ${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT indexOf(['a', 'b', NULL], toLowCardinality('a'))"
}

for _ in `seq 1 32`; do go | grep "Exception" && echo 'FAIL' || echo 'OK' ||: & done

wait

${DATASTORE_CLIENT} --multiline --query="""
DROP TABLE IF EXISTS t_01411;
DROP TABLE IF EXISTS t_01411_num;
"""
