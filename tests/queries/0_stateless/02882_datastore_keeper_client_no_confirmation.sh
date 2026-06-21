#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

path="/test-keeper-client-$DATASTORE_DATABASE"

$DATASTORE_KEEPER_CLIENT -q "rm '$path'" >& /dev/null

$DATASTORE_KEEPER_CLIENT -q "create '$path' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "rmr '$path'"
$DATASTORE_KEEPER_CLIENT -q "get '$path'" 2>&1
