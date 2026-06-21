#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

URL="${DATASTORE_PORT_HTTP_PROTO}://default:invalid_password@${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/"
${DATASTORE_CURL} -v "$URL?query=SELECT%201" 2>&1 | grep -P '401 Unauthorized|WWW-Authenticate'
