#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# If the Authorization is set to "never", the credentials in the headers are ignored:
URL="${DATASTORE_PORT_HTTP_PROTO}://default:invalid_password@${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/"
${DATASTORE_CURL} -H 'Authorization: never' "$URL?query=SELECT%201"

# If the Authorization is set to "never", and the credentials are provided in URL parameters,
# the server will return 403 instead of 401 Unauthorized, so there will be no prompt in the browser.
URL="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/?user=default&password=invalid_password"
${DATASTORE_CURL} -H 'Authorization: never' -v "$URL?query=SELECT%201" 2>&1 | grep -P '403 Forbidden|Datastore Cloud'
