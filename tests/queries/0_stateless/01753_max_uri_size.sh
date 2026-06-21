#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# NOTE: since 'max_uri_size' doesn't affect the request itself, this test hardly depends on the default value of this setting (1 MiB).

python3 -c "
print('${DATASTORE_URL}', end='')
print('&hello=world'*100000, end='')
print('&query=SELECT+1')
" > "${DATASTORE_TMP}/url.txt"

wget --input-file "${DATASTORE_TMP}/url.txt" 2>&1 | grep -Fc "400: Bad Request"

rm "${DATASTORE_TMP}/url.txt"
