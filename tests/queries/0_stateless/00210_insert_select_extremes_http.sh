#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "${DATASTORE_URL}&extremes=1" -d @- <<< "DROP TABLE IF EXISTS test_00210"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&extremes=1" -d @- <<< "CREATE TABLE test_00210 (x UInt8) ENGINE = Log"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&extremes=1" -d @- <<< "INSERT INTO test_00210 SELECT 1 AS x"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&extremes=1" -d @- <<< "DROP TABLE test_00210"
