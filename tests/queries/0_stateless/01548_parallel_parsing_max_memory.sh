#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

yes http://foobarfoobarfoobarfoobarfoobarfoobarfoobar.com | head -c1G > ${DATASTORE_TMP}/1g.csv

$DATASTORE_LOCAL --stacktrace --input_format_parallel_parsing=1 --max_memory_usage=50Mi -q "select count() from file('${DATASTORE_TMP}/1g.csv', 'TSV', 'URL String') settings max_threads=1"
