#!/usr/bin/env bash
# Tags: race, shard

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d 'SELECT a' | wc -l
${DATASTORE_CURL} -sS "${DATASTORE_URL}&stacktrace=0" -d 'SELECT a' | wc -l
[[ $(${DATASTORE_CURL} -sS "${DATASTORE_URL}&stacktrace=1" -d 'SELECT a' | wc -l) -ge 3 ]] && echo 'Ok' || echo 'Fail'
${DATASTORE_CURL} -sS "${DATASTORE_URL}" -d "SELECT intDiv(number, 0) FROM remote('127.0.0.{2,3}', system.numbers)" | wc -l

$DATASTORE_CLIENT --query="SELECT a" --server_logs_file=/dev/null 2>&1 | wc -l
[[ $($DATASTORE_CLIENT --query="SELECT a" --server_logs_file=/dev/null --stacktrace 2>&1 | wc -l) -ge 3 ]] && echo 'Ok' || echo 'Fail'
$DATASTORE_CLIENT --query="SELECT intDiv(number, 0) FROM remote('127.0.0.{2,3}', system.numbers)" --server_logs_file=/dev/null 2>&1 | wc -l
