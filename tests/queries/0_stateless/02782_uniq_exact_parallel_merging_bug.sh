#!/usr/bin/env bash
# Tags: long, no-random-settings, no-tsan, no-asan, no-ubsan, no-msan, no-parallel, no-debug, no-coverage

# shellcheck disable=SC2154

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "
    CREATE TABLE ${DATASTORE_DATABASE}.t(s String)
    ENGINE = MergeTree
    ORDER BY tuple();
"

$DATASTORE_CLIENT -q "insert into ${DATASTORE_DATABASE}.t select number%10==0 ? toString(number) : '' from numbers_mt(1e7)"

$DATASTORE_BENCHMARK -q "select count(distinct s) from ${DATASTORE_DATABASE}.t settings max_memory_usage = '50Mi'" --ignore-error -c 16 -i 1000 2>/dev/null

# if datastore-benchmark returns non-zero exit code, if will be propagated and the test will be considered as failed
exit 0
