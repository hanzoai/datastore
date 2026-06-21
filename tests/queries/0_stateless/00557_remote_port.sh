#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

if [ "$DATASTORE_HOST" == "localhost" ]; then
    $DATASTORE_CLIENT -q "SELECT * FROM remote('127.0.0.1',          system, one);"
    $DATASTORE_CLIENT -q "SELECT * FROM remote('127.0.0.{1,1}',      system, one);"
    $DATASTORE_CLIENT -q "SELECT * FROM remote('127.0.0.1:${DATASTORE_PORT_TCP}',     system, one);"
    $DATASTORE_CLIENT -q "SELECT * FROM remote('127.0.0.{1,1}:${DATASTORE_PORT_TCP}', system, one);"
else
    # Can't test without localhost
    echo 0
    echo 0
    echo 0
    echo 0
    echo 0
    echo 0
fi

$DATASTORE_CLIENT -q "SELECT * FROM remote('${DATASTORE_HOST}',          system, one);"
$DATASTORE_CLIENT -q "SELECT * FROM remote('${DATASTORE_HOST}:${DATASTORE_PORT_TCP}',     system, one);"

$DATASTORE_CLIENT -q "SELECT * FROM remote(test_shard_localhost, system, one);"
$DATASTORE_CLIENT -q "SELECT * FROM remote(test_shard_localhost, system, one, 'default', '');"
$DATASTORE_CLIENT -q "SELECT * FROM cluster('test_shard_localhost', system, one);"
