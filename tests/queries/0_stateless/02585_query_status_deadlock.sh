#!/usr/bin/env bash
# Tags: long

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

QUERY_ID="${DATASTORE_DATABASE}_test_02585_query_to_kill_id_1"

$DATASTORE_CLIENT --query_id="$QUERY_ID" --max_rows_to_read 0 -q "
create temporary table tmp as select * from numbers(100000000);
select * from remote('127.0.0.2', 'system.numbers_mt') where number in (select * from tmp);" &> /dev/null &

$DATASTORE_CLIENT -q "SYSTEM FLUSH LOGS query_log"

while true
do
    res=$($DATASTORE_CLIENT -q "select query, event_time from system.query_log where event_date >= yesterday() AND event_time >= now() - 600 AND query_id = '$QUERY_ID' and current_database = '$DATASTORE_DATABASE' and query like 'select%' limit 1")
    if [ -n "$res" ]; then
        break
    fi
    sleep 1
done

$DATASTORE_CLIENT -q "kill query where query_id = '$QUERY_ID' sync" &> /dev/null
