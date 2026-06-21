#!/usr/bin/env bash
# Tags: long, no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

query="SELECT toDate('2020-12-12') as datetime, 'test-pipeline' as pipeline, 'datastore-test-host-001.datastore.com' as host, 'datastore' as home, 'datastore' as detail, number as row_number FROM numbers(1000000) SETTINGS max_block_size=65505 FORMAT JSON"

${DATASTORE_CURL} -sS -H 'Accept-Encoding: zstd' \
    "${DATASTORE_URL}&enable_http_compression=1" -d "${query}" |& zstdX 2>/dev/null ||:
