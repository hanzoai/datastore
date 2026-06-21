#!/usr/bin/env bash
set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} "${DATASTORE_URL}&query=select" -X POST --form-string 'query= 1;' 2>/dev/null

echo -ne '1,Hello\n2,World\n' | ${DATASTORE_CURL} -sS -F 'file=@-' "${DATASTORE_URL}&file_format=CSV&file_types=UInt8,String&query=SELE" -X POST --form-string 'query=CT * FROM file' 2>/dev/null
