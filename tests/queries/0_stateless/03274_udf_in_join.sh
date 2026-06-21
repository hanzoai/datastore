#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "
  CREATE VIEW v0 AS SELECT 1 AS c0;
  CREATE FUNCTION ${DATASTORE_DATABASE}_second AS (x, y) -> y;
  CREATE FUNCTION ${DATASTORE_DATABASE}_equals AS (x, y) -> x = y;
  EXPLAIN PLAN SELECT 1 FROM v0 JOIN v0 vx ON ${DATASTORE_DATABASE}_second(v0.c0, vx.c0); -- { serverError INVALID_JOIN_ON_EXPRESSION }
  EXPLAIN SYNTAX SELECT 1 FROM v0 JOIN v0 vx ON ${DATASTORE_DATABASE}_equals(v0.c0, vx.c0);

  SELECT 1 FROM v0 JOIN v0 vx ON ${DATASTORE_DATABASE}_equals(v0.c0, vx.c0);

  DROP view v0;
  DROP FUNCTION ${DATASTORE_DATABASE}_second;
  DROP FUNCTION ${DATASTORE_DATABASE}_equals;
"
