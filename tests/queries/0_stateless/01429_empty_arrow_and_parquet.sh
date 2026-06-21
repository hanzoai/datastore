#!/usr/bin/env bash
# Tags: no-fasttest

set -e
# Fail `A | B` if A fails.
set -o pipefail

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS test_empty_data"
${DATASTORE_CLIENT} --query="CREATE TABLE test_empty_data (x Int8) ENGINE = Memory"

(echo "INSERT INTO test_empty_data FORMAT Arrow" && ${DATASTORE_CLIENT} --query="SELECT 1 AS x FORMAT Arrow") | ${DATASTORE_CLIENT}
${DATASTORE_CLIENT} --query="SELECT count() FROM test_empty_data"
(echo "INSERT INTO test_empty_data FORMAT Arrow" && ${DATASTORE_CLIENT} --query="SELECT 1 AS x LIMIT 0 FORMAT Arrow") | ${DATASTORE_CLIENT}
${DATASTORE_CLIENT} --query="SELECT count() FROM test_empty_data"
(echo "INSERT INTO test_empty_data FORMAT ArrowStream" && ${DATASTORE_CLIENT} --query="SELECT 1 AS x FORMAT ArrowStream") | ${DATASTORE_CLIENT}
${DATASTORE_CLIENT} --query="SELECT count() FROM test_empty_data"
(echo "INSERT INTO test_empty_data FORMAT ArrowStream" && ${DATASTORE_CLIENT} --query="SELECT 1 AS x LIMIT 0 FORMAT ArrowStream") | ${DATASTORE_CLIENT}
${DATASTORE_CLIENT} --query="SELECT count() FROM test_empty_data"
(echo "INSERT INTO test_empty_data FORMAT Parquet" && ${DATASTORE_CLIENT} --query="SELECT 1 AS x FORMAT Parquet") | ${DATASTORE_CLIENT}
${DATASTORE_CLIENT} --query="SELECT count() FROM test_empty_data"
(echo "INSERT INTO test_empty_data FORMAT Parquet" && ${DATASTORE_CLIENT} --query="SELECT 1 AS x LIMIT 0 FORMAT Parquet") | ${DATASTORE_CLIENT}
${DATASTORE_CLIENT} --query="SELECT count() FROM test_empty_data"

${DATASTORE_CLIENT} -q "DROP TABLE test_empty_data"

# Test with datastore-local too. (It used to crash because header block had const columns.)
$DATASTORE_LOCAL -q "select 1 as x where 0 format Arrow" | $DATASTORE_LOCAL --input-format Arrow --structure="x Int8" -q "select count() from table"
$DATASTORE_LOCAL -q "select 1 as x where 0 format ArrowStream" | $DATASTORE_LOCAL --input-format ArrowStream --structure="x Int8" -q "select count() from table"
$DATASTORE_LOCAL -q "select 1 as x where 0 format Parquet" | $DATASTORE_LOCAL --input-format Parquet --structure="x Int8" -q "select count() from table"
