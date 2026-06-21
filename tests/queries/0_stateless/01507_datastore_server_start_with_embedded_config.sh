#!/usr/bin/env bash
# Tags: no-parallel

DATASTORE_PORT_TCP=50111
DATASTORE_DATABASE=default

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "Starting datastore-server"

$DATASTORE_BINARY server -- --tcp_port "$DATASTORE_PORT_TCP" --path "${DATASTORE_TMP}/" > "${DATASTORE_TMP}/server.log" 2>&1 &
PID=$!

function finish()
{
    kill $PID
    wait
}
trap finish EXIT

echo "Waiting for datastore-server to start"

for i in {1..30}; do
    sleep 1
    $DATASTORE_CLIENT --query "SELECT 1" 2>/dev/null && break
    if [[ $i == 30 ]]; then
        cat "${DATASTORE_TMP}/server.log"
        exit 1
    fi
done

# Check access rights

$DATASTORE_CLIENT --query "
    DROP DATABASE IF EXISTS ${DATASTORE_DATABASE_1};
    CREATE DATABASE ${DATASTORE_DATABASE_1};
    USE ${DATASTORE_DATABASE_1};

    CREATE TABLE t (s String) ENGINE=TinyLog;
    INSERT INTO t VALUES ('Hello');
    SELECT * FROM t;
    DROP TABLE t;

    CREATE TEMPORARY TABLE t (s String);
    INSERT INTO t VALUES ('World');
    SELECT * FROM t;
"

kill $PID
# Dump server.log in case wait hangs
function trace()
{
    # datastore-test prints only stderr on timeouts
    cat "${DATASTORE_TMP}/server.log" >&2
}
trap trace EXIT
wait
trap '' EXIT
