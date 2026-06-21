#!/usr/bin/env bash
# Tags: no-parallel-replicas

set -e
CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS t_04099"
${DATASTORE_CLIENT} --query="CREATE TABLE t_04099 (a UInt32, b String, extra String) ENGINE=Memory"

${DATASTORE_CLIENT} --query="SELECT number::UInt32 AS a, 'val' AS b FROM numbers(3) FORMAT Native" | \
    ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+t_04099+SELECT+*,+%27const%27+AS+extra+FROM+input(%27auto%27)+FORMAT+Native" --data-binary @-

${DATASTORE_CLIENT} --query="SELECT * FROM t_04099 ORDER BY a"
${DATASTORE_CLIENT} --query="TRUNCATE TABLE t_04099"

${DATASTORE_CLIENT} --query="SELECT 'val' AS b FROM numbers(3) FORMAT Native" | \
    ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+t_04099+(b)+SELECT+*+FROM+input(%27auto%27)+FORMAT+Native" --data-binary @-

${DATASTORE_CLIENT} --query="SELECT * FROM t_04099 ORDER BY b"
${DATASTORE_CLIENT} --query="TRUNCATE TABLE t_04099"

${DATASTORE_CLIENT} --query="SELECT number::UInt32 AS a, 'val' AS b FROM numbers(3) FORMAT Native" | \
    ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+t_04099(*+EXCEPT+extra)+SELECT+*+FROM+input(%27auto%27)+FORMAT+Native" --data-binary @-

${DATASTORE_CLIENT} --query="SELECT * FROM t_04099 ORDER BY a"

${DATASTORE_CLIENT} --query="DROP TABLE t_04099"
