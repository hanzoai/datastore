#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

RETRIES=5

# do not trust DATASTORE_URL var because it contains randomization settings
DATASTORE_URL_LOCAL="${DATASTORE_PORT_HTTP_PROTO}://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/"

query="SELECT name, value, changed FROM system.settings WHERE name='output_format_parallel_formatting'"

echo "output_format_parallel_formatting=1"
${DATASTORE_CURL} -sS "${DATASTORE_URL_LOCAL}?output_format_parallel_formatting=1" -d "$query"
echo "output_format_parallel_formatting=0"
${DATASTORE_CURL} -sS "${DATASTORE_URL_LOCAL}?output_format_parallel_formatting=0" -d "$query"
echo "output_format_parallel_formatting=1&output_format_parallel_formatting=0"
${DATASTORE_CURL} -sS "${DATASTORE_URL_LOCAL}?output_format_parallel_formatting=1&output_format_parallel_formatting=0" -d "$query"
echo "output_format_parallel_formatting=0&output_format_parallel_formatting=1"
${DATASTORE_CURL} -sS "${DATASTORE_URL_LOCAL}?output_format_parallel_formatting=0&output_format_parallel_formatting=1" -d "$query"
