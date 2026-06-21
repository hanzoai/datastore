#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -s "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/binary" 2>/dev/null | grep -oF --max-count 1 'addressToSymbol'
