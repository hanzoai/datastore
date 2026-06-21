#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel-replicas

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS t0, t1, v0"
$DATASTORE_CLIENT -q "CREATE TABLE t0 (c0 Int) ENGINE = MergeTree() ORDER BY tuple()"
$DATASTORE_CLIENT -q "CREATE TABLE IF NOT EXISTS t1 (c0 Int) ENGINE = IcebergS3(s3_conn, filename = '03800_mv_from_iceberg/t1_${DATASTORE_TEST_UNIQUE_NAME}')"
$DATASTORE_CLIENT -q "CREATE MATERIALIZED VIEW v0 TO t0 AS (SELECT c0 FROM t1)"
$DATASTORE_CLIENT -q "INSERT INTO TABLE t1 (c0) SETTINGS allow_insert_into_iceberg = 1 VALUES (1)"
