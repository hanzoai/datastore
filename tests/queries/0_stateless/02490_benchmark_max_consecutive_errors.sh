#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_BENCHMARK -q 'select throwIf(1)' |& grep "DB::Exception: Value passed to 'throwIf' function is non-zero" -c
RES=$($DATASTORE_BENCHMARK --max-consecutive-errors 10 -q 'select throwIf(1)' |& tee "${DATASTORE_TMP}/${DATASTORE_DATABASE}.log" | grep "DB::Exception: Value passed to 'throwIf' function is non-zero" -c)

if [ "$RES" -eq 10 ]
then
    echo "$RES"
else
    echo "$RES"
    cat "${DATASTORE_TMP}/${DATASTORE_DATABASE}.log"
fi
