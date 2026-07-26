#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# the sed command here replaces the real number of left requests with a question mark, because it can vary and we don't really have control over it
( ${DATASTORE_CURL} -s --head "${DATASTORE_URL}&query=SELECT%201" | sed -r 's/(keep-alive: timeout=30, max=)[0-9]+/\1?/I';
  ${DATASTORE_CURL} -s --head "${DATASTORE_URL}&query=select+*+from+system.numbers+limit+1000000" ) | sed -r 's/(keep-alive: timeout=30, max=)[0-9]+/\1?/I' | grep -v "Date:" | grep -v "X-Datastore-Server-Display-Name:" | grep -v "X-Datastore-Query-Id:" | grep -v "X-Datastore-Format:" | grep -v "X-Datastore-Timezone:" | grep -v "X-Datastore-Exception-Tag:"

if [[ $(${DATASTORE_CURL} -sS -X POST -I "${DATASTORE_URL}&query=SELECT+1" | grep -c '411 Length Required') -ne 1 ]]; then
    echo FAIL
fi
