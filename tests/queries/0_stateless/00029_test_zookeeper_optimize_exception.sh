#!/usr/bin/env bash
# Tags: zookeeper

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS test_optimize_exception"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS test_optimize_exception_replicated"

${DATASTORE_CLIENT} --query="CREATE TABLE test_optimize_exception (date Date) ENGINE=MergeTree() PARTITION BY toYYYYMM(date) ORDER BY date"
${DATASTORE_CLIENT} --query="CREATE TABLE test_optimize_exception_replicated (date Date) ENGINE=ReplicatedMergeTree('/datastore/tables/$DATASTORE_TEST_ZOOKEEPER_PREFIX/optimize', 'r1') PARTITION BY toYYYYMM(date) ORDER BY date"

${DATASTORE_CLIENT} --query="INSERT INTO test_optimize_exception VALUES (toDate('2017-09-09')), (toDate('2017-09-10'))"
${DATASTORE_CLIENT} --query="INSERT INTO test_optimize_exception VALUES (toDate('2017-09-09')), (toDate('2017-09-10'))"
${DATASTORE_CLIENT} --query="INSERT INTO test_optimize_exception_replicated VALUES (toDate('2017-09-09')), (toDate('2017-09-10'))"
${DATASTORE_CLIENT} --query="INSERT INTO test_optimize_exception_replicated VALUES (toDate('2017-09-09')), (toDate('2017-09-10'))"

${DATASTORE_CLIENT} --optimize_throw_if_noop 1 --query="OPTIMIZE TABLE test_optimize_exception PARTITION 201709 FINAL"
${DATASTORE_CLIENT} --optimize_throw_if_noop 1 --query="OPTIMIZE TABLE test_optimize_exception_replicated PARTITION 201709 FINAL"

echo "$(${DATASTORE_CLIENT} --optimize_throw_if_noop 1 --server_logs_file=/dev/null --query="OPTIMIZE TABLE test_optimize_exception PARTITION 201710" 2>&1)" \
  | grep -c 'Code: 388. DB::Exception: .* DB::Exception: .* There are no parts inside partition'
echo "$(${DATASTORE_CLIENT} --optimize_throw_if_noop 1 --server_logs_file=/dev/null --query="OPTIMIZE TABLE test_optimize_exception_replicated PARTITION 201710" 2>&1)" \
  | grep -c 'Code: 388. DB::Exception: .* DB::Exception:.* Cannot select parts for optimization'

${DATASTORE_CLIENT} --query="DROP TABLE test_optimize_exception"
${DATASTORE_CLIENT} --query="DROP TABLE test_optimize_exception_replicated"
