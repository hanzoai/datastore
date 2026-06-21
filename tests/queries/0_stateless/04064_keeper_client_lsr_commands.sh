#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

path="/test-keeper-client-$DATASTORE_DATABASE"
$DATASTORE_KEEPER_CLIENT -q "rmr '$path'" >& /dev/null || true

$DATASTORE_KEEPER_CLIENT -q "create '$path' 'root'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/T' 'x'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/T/A' 'x'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/T/A/B' 'x'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/T/C' 'x'"

echo 'lsr explicit path'
$DATASTORE_KEEPER_CLIENT -q "lsr '$path' 100"

echo 'lsr path 2'
$DATASTORE_KEEPER_CLIENT -q "lsr '$path' 2"

echo 'lsr from cwd'
$DATASTORE_KEEPER_CLIENT -q "cd '$path'; lsr 100"

echo 'cleanup'
$DATASTORE_KEEPER_CLIENT -q "rmr '$path'"
