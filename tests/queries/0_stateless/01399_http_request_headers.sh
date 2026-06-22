#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'EmptyHeader;' -d 'SELECT 1'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-User: default' -d 'SELECT 1'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-User: header_test' -d 'SELECT 1' | grep -o 'Code: 516'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Key: ' -d 'SELECT 1'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Key: header_test' -d 'SELECT 1' | grep -o 'Code: 516'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Quota: ' -d 'SELECT 1'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Quota: header_test' -d 'SELECT 1'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Database: system' -d 'SHOW TABLES' | grep -o 'processes'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Database: header_test' -d 'SHOW TABLES' | grep -o 'Code: 81'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Format: JSONCompactEachRow' -d 'SELECT 1' | grep -o '\[1\]'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}" -H 'X-Datastore-Format: header_test' -d 'SELECT 1' | grep -o 'Code: 73'
${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}&quota_key=pingpong" -H 'X-Datastore-User: default' -d 'SELECT 1'
