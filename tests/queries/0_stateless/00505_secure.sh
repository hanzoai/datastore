#!/usr/bin/env bash
# Tags: no-fasttest, no-random-settings

# set -x

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --no-secure -q "SELECT 0;"

# Use $DATASTORE_CLIENT_SECURE, but replace `--secure` by `-s` to test it
DATASTORE_CLIENT_S=${DATASTORE_CLIENT_SECURE/ --secure / -s }
$DATASTORE_CLIENT_S -q "SELECT 1;"

$DATASTORE_CLIENT_SECURE -q "SELECT 2;"

$DATASTORE_CURL -sS --insecure "${DATASTORE_URL_HTTPS}&query=SELECT%203"

$DATASTORE_CLIENT_SECURE -q "SELECT 4;"

# TODO: can test only on unchanged port. Possible solutions: generate config or pass shard port via command line
if [[ "$DATASTORE_PORT_TCP_SECURE" = "$DATASTORE_PORT_TCP_SECURE" ]]; then
    cat "$CURDIR"/00505_distributed_secure.data | $DATASTORE_CLIENT_SECURE -m
else
    tail -n 13 "$CURDIR"/00505_secure.reference
fi

