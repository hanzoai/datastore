#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Test that clickstack UI is accessible and serves correct content
${DATASTORE_CURL} --compressed -sS "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/clickstack" | grep -oF 'ClickStack' | head -n 1

# Test that clickstack serves with gzip encoding
${DATASTORE_CURL} -sS -I "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/clickstack" | grep -oF 'Content-Encoding: gzip'

# Test that 404 is returned for non-existent resources
${DATASTORE_CURL} -sS "${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/clickstack/nonexistent" | grep -oF 'Not found'
