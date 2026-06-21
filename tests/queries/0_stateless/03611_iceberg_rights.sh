#!/usr/bin/env bash
# Tags: no-fasttest, no-replicated-database, memory-engine

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

mkdir "${DATASTORE_TMP}/foo"
$DATASTORE_CLIENT -m -q "
DROP TABLE IF EXISTS t0;
CREATE TABLE t0 (c0 Nullable(Int)) ENGINE = IcebergLocal('${DATASTORE_TMP}/foo'); -- { serverError PATH_ACCESS_DENIED }
"
