#!/usr/bin/env bash

set -e

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

cd "$DATASTORE_TMP"

# Simple Buffers round-trip via stdout/stdin using datastore-local

# Producer: write Buffers to a temp file
$DATASTORE_LOCAL \
    --structure 'id UInt64' \
    --query "SELECT number AS id FROM numbers(10)" \
    --output-format Buffers \
    > 03743_buffers_stream_numbers.buffers

# Consumer: read Buffers from stdin and aggregate
$DATASTORE_LOCAL \
    --structure 'id UInt64' \
    --input-format Buffers \
    --query "SELECT sum(id) FROM table" \
    < 03743_buffers_stream_numbers.buffers

rm -f 03743_buffers_stream_numbers.buffers
