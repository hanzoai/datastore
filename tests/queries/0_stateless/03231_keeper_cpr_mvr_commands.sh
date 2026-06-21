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

echo 'copy'
$DATASTORE_KEEPER_CLIENT -q "cpr '$path/A' '$path/D'"
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"
$DATASTORE_KEEPER_CLIENT -q "get '$path/D'"
$DATASTORE_KEEPER_CLIENT -q "get '$path/D/B'"

echo 'move'
$DATASTORE_KEEPER_CLIENT -q "mvr '$path/D' '$path/H'"
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"
$DATASTORE_KEEPER_CLIENT -q "get '$path/H'"
$DATASTORE_KEEPER_CLIENT -q "get '$path/H/B'"

echo 'copy to existing'
$DATASTORE_KEEPER_CLIENT -q "cpr '$path/H' '$path/C'" 2>&1
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"

echo 'move to existing'
$DATASTORE_KEEPER_CLIENT -q "mvr '$path/H' '$path/C'" 2>&1
$DATASTORE_KEEPER_CLIENT -q "ls '$path'"

echo 'clean up'
$DATASTORE_KEEPER_CLIENT -q "rmr '$path'"
