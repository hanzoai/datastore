#!/usr/bin/env bash

# shellcheck source=../shell_config.sh
CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

# This is random garbage, so compression ratio will be very low.
tr -cd 'a-z0-9' < /dev/urandom | head -c1M > ${DATASTORE_TMP}/input

# stdin/stdout streams
$DATASTORE_COMPRESSOR < ${DATASTORE_TMP}/input > ${DATASTORE_TMP}/output
diff -q <($DATASTORE_COMPRESSOR --decompress < ${DATASTORE_TMP}/output) ${DATASTORE_TMP}/input

# positional arguments, and that fact that input/output will be overwritten
$DATASTORE_COMPRESSOR ${DATASTORE_TMP}/input ${DATASTORE_TMP}/output
diff -q <($DATASTORE_COMPRESSOR --decompress ${DATASTORE_TMP}/output) ${DATASTORE_TMP}/input

# --offset-in-decompressed-block
diff -q <($DATASTORE_COMPRESSOR --decompress --offset-in-decompressed-block 10 ${DATASTORE_TMP}/output) <(tail -c+$((10+1)) ${DATASTORE_TMP}/input)

# TODO: --offset-in-compressed-file using some .bin file (via datastore-local + check-marks)
