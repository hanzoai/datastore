#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CURL} --raw -sS "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/js/uplot.js" | grep -F 'HTTP/' ||:
