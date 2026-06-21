#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

touch "${DATASTORE_TMP}/test_exception"
function cleanup()
{
    rm "${DATASTORE_TMP}/test_exception"
}
trap cleanup EXIT
$DATASTORE_LOCAL --query="SELECT 1 INTO OUTFILE '${DATASTORE_TMP}/test_exception' FORMAT Native" 2>&1 | grep -q "Code: 504. DB::Exception:" && echo 'OK' || echo 'FAIL' ||:
