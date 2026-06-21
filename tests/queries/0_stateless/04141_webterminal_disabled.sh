#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# By default, allow_experimental_webterminal is false, so /webterminal must return 403.
${DATASTORE_CURL} -sS -o /dev/null -w "%{http_code}\n" \
    "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/webterminal"

# HEAD requests are also gated and must return 403.
${DATASTORE_CURL} -sS -I -o /dev/null -w "%{http_code}\n" \
    "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/webterminal"

# Body content reflects the configuration hint about the experimental setting.
${DATASTORE_CURL} -sS \
    "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/webterminal" \
    | grep -o 'allow_experimental_webterminal'
