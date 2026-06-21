#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

path="/test-keeper-client-$DATASTORE_DATABASE"
$DATASTORE_KEEPER_CLIENT -q "rm '$path'" >& /dev/null

$DATASTORE_KEEPER_CLIENT -q "create '$path' 'root'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/A' 'node-A'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/A/B' 'node-B'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/C' 'node-B'"

echo 'initial'
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"

echo 'simple copy'
$DATASTORE_KEEPER_CLIENT -q "cp '$path/A' '$path/D'"
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"
$DATASTORE_KEEPER_CLIENT -q "get '$path/D'"

echo 'simple move'
$DATASTORE_KEEPER_CLIENT -q "mv '$path/D' '$path/H'"
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"
$DATASTORE_KEEPER_CLIENT -q "get '$path/H'"

echo 'move node with childs -- must be error'
$DATASTORE_KEEPER_CLIENT -q "mv '$path/A' '$path/ERROR'" 2>&1
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"

echo 'move node to existing'
$DATASTORE_KEEPER_CLIENT -q "mv '$path/C' '$path/A'" 2>&1
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"

echo 'clean up'
$DATASTORE_KEEPER_CLIENT -q "rmr '$path'"
