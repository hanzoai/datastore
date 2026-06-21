#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} --max-time 1 -sS "${DATASTORE_URL}&query_id=cancel_http_readonly_queries_on_client_close&cancel_http_readonly_queries_on_client_close=1&max_rows_to_read=0&query=SELECT+count()+FROM+system.numbers" 2>&1 | grep -cF 'curl: (28)'

i=0 retries=300
while [[ $i -lt $retries ]]; do
    ${DATASTORE_CURL} -sS --data "SELECT count() FROM system.processes WHERE query_id = 'cancel_http_readonly_queries_on_client_close'" "${DATASTORE_URL}" | grep '0' && break
    ((++i))
    sleep 0.2
done

${DATASTORE_CURL} -sS -X POST "${DATASTORE_URL}&session_id=test_00834_session&readonly=2&cancel_http_readonly_queries_on_client_close=1" -d "CREATE TEMPORARY TABLE table_tmp AS SELECT 1 FORMAT JSON"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&session_id=test_00834_session&query=DROP+TEMPORARY+TABLE+table_tmp"

url_https="https://${DATASTORE_HOST}:${DATASTORE_PORT_HTTPS}/?session_id=test_00834_session"
${DATASTORE_CURL} -sSk -X POST "$url_https&readonly=2&cancel_http_readonly_queries_on_client_close=1" -d "CREATE TEMPORARY TABLE table_tmp AS SELECT 1 FORMAT JSON"
${DATASTORE_CURL} -sSk "$url_https&session_id=test_00834_session&query=DROP+TEMPORARY+TABLE+table_tmp"
