#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "$DATASTORE_URL" -d 'SELECT floor(NULL), 1;';
${DATASTORE_CURL} -sS "$DATASTORE_URL" -d 'SELECT toInt64(null), 2';
${DATASTORE_CURL} -sS "$DATASTORE_URL" -d 'SELECT floor(NULL) FORMAT JSONEachRow;';
${DATASTORE_CURL} -sS "$DATASTORE_URL" -d 'SELECT floor(greatCircleDistance(NULL, 55.3, 38.7, 55.1)) AS distance format JSONEachRow;';
${DATASTORE_CURL} -sS "$DATASTORE_URL" -d 'SELECT NULL + 1;';
