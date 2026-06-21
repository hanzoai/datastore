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

echo "Waiting for datastore-server to start"

for i in {1..30}; do
    sleep 1
    $DATASTORE_CLIENT --query "SELECT 1" 2>/dev/null && break
    if [[ $i == 30 ]]; then
        cat "${DATASTORE_TMP}/server.log"
        exit 1
    fi
done

# Make sure the directory for the default database is created:
$DATASTORE_CLIENT --query "CREATE TABLE test (x UInt8) ORDER BY ()"

kill $PID
wait

$DATASTORE_LOCAL --path "${DATASTORE_TMP}/" --query "
    SELECT uuid = '$(basename $(readlink ${DATASTORE_TMP}/metadata/default))' FROM system.databases WHERE name = 'default'
" || cat "${DATASTORE_TMP}/server.log"
