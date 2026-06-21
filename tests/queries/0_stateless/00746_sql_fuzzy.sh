#!/usr/bin/env bash
# Tags: no-fasttest, no-coverage

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

export SQL_FUZZY_FILE_FUNCTIONS=${DATASTORE_TMP}/datastore-functions
$DATASTORE_CLIENT -q "select name from system.functions format TSV;" > "$SQL_FUZZY_FILE_FUNCTIONS"

export SQL_FUZZY_FILE_TABLE_FUNCTIONS=${DATASTORE_TMP}/datastore-table_functions
$DATASTORE_CLIENT -q "select name from system.table_functions format TSV;" > "$SQL_FUZZY_FILE_TABLE_FUNCTIONS"

# This is short run for ordinary tests.
# if you want long run use: env SQL_FUZZY_RUNS=100000 datastore-test sql_fuzzy

for SQL_FUZZY_RUN in $(seq "${SQL_FUZZY_RUNS:=5}"); do
    env SQL_FUZZY_RUN="$SQL_FUZZY_RUN" perl "$CURDIR"/00746_sql_fuzzy.pl | timeout 60 $DATASTORE_CLIENT --format Null --max_execution_time 10 -n --ignore-error >/dev/null 2>&1
    if [[ $($DATASTORE_CLIENT -q "SELECT 'Still alive'") != 'Still alive' ]]; then
        break
    fi
done

$DATASTORE_CLIENT -q "SELECT 'Still alive'"

# Query replay:
# cat datastore-server.log  | grep -aF "<Debug> executeQuery: (from " | perl -lpe 's/^.*executeQuery: \(from \S+\) (.*)/$1;/' | datastore-client -n --ignore-error
