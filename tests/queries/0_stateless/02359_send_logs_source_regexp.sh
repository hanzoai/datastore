#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATASTORE_CLIENT_SERVER_LOGS_LEVEL=trace
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

[ ! -z "$DATASTORE_CLIENT_REDEFINED" ] && DATASTORE_CLIENT=$DATASTORE_CLIENT_REDEFINED

# automatic_parallel_replicas_mode: adds an unexpected log line with the source "InterpreterSelectQueryAnalyzer"
$DATASTORE_CLIENT --automatic_parallel_replicas_mode=0 --allow_experimental_analyzer=1 --send_logs_source_regexp "executeQuery|Interpreter|Planner" -q "SELECT 1 FORMAT Null" |& grep -o -E 'executeQuery|Interpreter|Planner' | LC_ALL=c sort -u
