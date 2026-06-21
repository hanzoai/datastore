#!/usr/bin/env bash
# Tags: race, no-parallel

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS mem"
$DATASTORE_CLIENT -q "CREATE TABLE mem (x UInt64) engine = Memory"

function f {
  local TIMELIMIT=$((SECONDS+$1))
  for _ in $(seq 1 300); do
    $DATASTORE_CLIENT -q "SELECT count() FROM (SELECT * FROM mem SETTINGS max_threads=2) FORMAT Null;"
    if [ $SECONDS -ge "$TIMELIMIT" ]; then
        break
    fi
  done
}

function g {
  local TIMELIMIT=$((SECONDS+$1))
  for _ in $(seq 1 100); do
    $DATASTORE_CLIENT -q "
        INSERT INTO mem SELECT number FROM numbers(1000000);
        INSERT INTO mem SELECT number FROM numbers(1000000);
        INSERT INTO mem SELECT number FROM numbers(1000000);
        INSERT INTO mem VALUES (1);
        INSERT INTO mem VALUES (1);
        INSERT INTO mem VALUES (1);
        INSERT INTO mem VALUES (1);
        INSERT INTO mem VALUES (1);
        INSERT INTO mem VALUES (1);
        TRUNCATE TABLE mem;
    "
    if [ $SECONDS -ge "$TIMELIMIT" ]; then
        break
    fi
  done
}

export -f f;
export -f g;

TIMEOUT=20
f $TIMEOUT &
g $TIMEOUT &
wait

$DATASTORE_CLIENT -q "DROP TABLE mem"
