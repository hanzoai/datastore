#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user="readonly"
address=${DATASTORE_HOST}
port=${DATASTORE_PORT_HTTP}
url="${DATASTORE_PORT_HTTP_PROTO}://${user}@${address}:${port}/?session_id=test"
select="SELECT name, value, changed FROM system.settings WHERE name = 'readonly'"

${DATASTORE_CURL} -sS "$url" --data-binary "$select"
