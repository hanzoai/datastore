#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

path="/test-keeper-client-$DATASTORE_DATABASE"

$DATASTORE_KEEPER_CLIENT -q "rm '$path'" >& /dev/null

$DATASTORE_KEEPER_CLIENT -q "create '$path' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/tmp-' 'foobar0' EPHEMERAL SEQUENTIAL"
$DATASTORE_KEEPER_CLIENT -q "create '$path/tmp-' 'foobar1' PERSISTENT SEQUENTIAL"
$DATASTORE_KEEPER_CLIENT -q "get '$path/tmp-0000000001'"
$DATASTORE_KEEPER_CLIENT -q "rmr '$path'"
