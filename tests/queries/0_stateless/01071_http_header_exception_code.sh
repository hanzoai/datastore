#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

if [[ $(${DATASTORE_CURL_COMMAND} -q -I "${DATASTORE_URL}&query=BADREQUEST" 2>&1 | grep -c 'X-Datastore-Exception-Code: 62') -eq 1 ]]; then
    echo "True"
fi
