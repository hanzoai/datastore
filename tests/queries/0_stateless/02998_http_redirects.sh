#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

URL="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}"

# Ping handler
${DATASTORE_CURL} -s -S "${URL}/"

# A handler that is configured to return a redirect
${DATASTORE_CURL} -s -S -I "${URL}/upyachka" | grep -i -P '^HTTP|Location'

# This handler is configured to not accept any query string
${DATASTORE_CURL} -s -S -I "${URL}/upyachka?hello=world" | grep -i -P '^HTTP|Location'

# Check that actual redirect works
${DATASTORE_CURL} -s -S -L "${URL}/upyachka"
