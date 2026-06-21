#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS -H 'Accept-Encoding: br'              "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT 1' | brotli -d
${DATASTORE_CURL} -sS -H 'Accept-Encoding: br,gzip'         "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT 1' | brotli -d
${DATASTORE_CURL} -sS -H 'Accept-Encoding: gzip,br'         "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT 1' | brotli -d
${DATASTORE_CURL} -sS -H 'Accept-Encoding: gzip,deflate,br' "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT 1' | brotli -d
${DATASTORE_CURL} -sS -H 'Accept-Encoding: gzip,deflate'    "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT 1' | gzip -d
${DATASTORE_CURL} -sS -H 'Accept-Encoding: gzip'            "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT number FROM numbers(1000000)' | gzip -d | tail -n3
${DATASTORE_CURL} -sS -H 'Accept-Encoding: br'              "${DATASTORE_URL}&enable_http_compression=1" -d 'SELECT number FROM numbers(1000000)' | brotli -d | tail -n3

