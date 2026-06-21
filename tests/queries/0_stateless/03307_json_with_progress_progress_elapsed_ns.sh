#!/usr/bin/env bash
# Tags: long

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# TODO: It looks like the elapsed time counted inside the format underestimates the total query processing time.
# TODO: It looks like the final progress packet is not always present.

${DATASTORE_CURL} -sS "${DATASTORE_URL}&default_format=JSONEachRowWithProgress" -d "SELECT sleep(0.1) FROM numbers(2) SETTINGS max_block_size = 1" | 
    grep -F '"progress"' | tail -n1 | grep -o -P '"elapsed_ns":"\d+"' | grep -o -P '\d+' | ${DATASTORE_LOCAL} --input-format TSV --query "SELECT c1 > 100_000_000 FROM table"
