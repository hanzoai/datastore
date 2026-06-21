#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo -ne 'checksumchecksum\x98\x90\x00\x00\x00\x11\x11\x11\x11\x04\x0f\x51                                                                                                                                       ' |
    ${DATASTORE_CURL} -sS "${DATASTORE_URL}&decompress=1&http_native_compression_disable_checksumming_on_decompress=1" --data-binary @- 2>&1 | grep -oF 'Exc'

echo -ne 'checksumchecksum\x98\x90\x00\x00\x00\x11\x11\x11\x11\x04\x0f\x16                                                                                                                                       ' |
    ${DATASTORE_CURL} -sS "${DATASTORE_URL}&decompress=1&http_native_compression_disable_checksumming_on_decompress=1" --data-binary @- 2>&1 | grep -oF 'Exc'
