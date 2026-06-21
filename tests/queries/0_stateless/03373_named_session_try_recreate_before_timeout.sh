#!/usr/bin/env bash
# Tags: no-encrypted-storage

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

export DATA_FILE="$DATASTORE_TMP/03373_session_test.tsv"
export SESSION="03373_session_${DATASTORE_DATABASE}"
export TABLE_NAME="03373_session_test"
export SESSION_ID="${SESSION}_$RANDOM.$RANDOM"
export SETTINGS="session_id=$SESSION_ID&session_timeout=3&throw_on_unsupported_query_inside_transaction=0"

$DATASTORE_CLIENT -q 'select * from numbers(100000) format TSV' > $DATA_FILE
$DATASTORE_CLIENT -q "create table $TABLE_NAME (A Int64) Engine = MergeTree order by sin(A) partition by intDiv(A, 10000)"

# set a setting to distinguish newly created named session from a reused one
$DATASTORE_CURL -sS -d 'set http_max_tries=3373' "$DATASTORE_URL&$SETTINGS"
$DATASTORE_CURL -sS -d "select value, changed from system.settings where name = 'http_max_tries'" "$DATASTORE_URL&$SETTINGS"

$DATASTORE_CURL -sS -d 'begin transaction' "$DATASTORE_URL&$SETTINGS"
$DATASTORE_CURL -sS -d 'commit' "$DATASTORE_URL&$SETTINGS&close_session=1"

# Deferred HTTP 100 response from Datastore prevents curl from sending body using potentially closed connection
$DATASTORE_CURL -sS -X POST -H "X-Datastore-100-Continue: defer" --data-binary @- \
  "$DATASTORE_URL&$SETTINGS&session_check=1&query=insert+into+$TABLE_NAME+format+TSV" \
  < "$DATA_FILE" 2>&1 | {
    response=$(cat)
    echo "$response" | grep -Faq "SESSION_NOT_FOUND" || {
        echo "Expected SESSION_NOT_FOUND error"
        echo "---- FULL RESPONSE START ----"
        echo "$response"
        echo "---- FULL RESPONSE END ----"
        exit 1
    }
  }
$DATASTORE_CLIENT --implicit_transaction=1 -q "select throwIf(count() != 0) from $TABLE_NAME" \
  || $DATASTORE_CLIENT -q "select name, rows, active, visible, creation_tid, creation_csn from system.parts where database=currentDatabase()"

# sleep a bit more than a session timeout (3) to make sure there's enough time to close it using close time buckets
sleep 5

$DATASTORE_CURL -sS -d "select value, changed from system.settings where name = 'http_max_tries'" "$DATASTORE_URL&$SETTINGS"
$DATASTORE_CURL -sS -X POST --max-time 300 --data-binary @- "$DATASTORE_URL&$SETTINGS&query=insert+into+$TABLE_NAME+format+TSV" < $DATA_FILE
$DATASTORE_CLIENT --implicit_transaction=1 -q "select throwIf(count() != 100000) from $TABLE_NAME" \
  || $DATASTORE_CLIENT -q "select name, rows, active, visible, creation_tid, creation_csn from system.parts where database=currentDatabase()"

$DATASTORE_CLIENT -q "drop table $TABLE_NAME"
