#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

export DATASTORE_URL="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/"

${DATASTORE_CURL} -sS "${DATASTORE_URL}sashboards" | grep -o ".* Maybe you meant /dashboard"
${DATASTORE_CURL} -sS "${DATASTORE_URL}sashboard"  | grep -o ".* Maybe you meant /dashboard"
${DATASTORE_CURL} -sS "${DATASTORE_URL}sashboarb"  | grep -o ".* Maybe you meant /dashboard"
${DATASTORE_CURL} -sS "${DATASTORE_URL}sashboaxb"  | grep -o ".* Maybe you meant /dashboard"
