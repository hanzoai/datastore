#!/usr/bin/env bash
# Tags: no-parallel

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "DROP USER IF EXISTS u_02377"
${DATASTORE_CLIENT} -q "drop quota if exists q_02377"
${DATASTORE_CLIENT} -q "CREATE USER u_02377 IDENTIFIED WITH plaintext_password BY 'password';"
${DATASTORE_CLIENT} -q "CREATE QUOTA q_02377 KEYED BY client_key FOR INTERVAL 1 month MAX queries = 100 TO u_02377;"

${DATASTORE_CLIENT} --user=u_02377 --password=password --quota_key=q_02377 --query="select 1"

${DATASTORE_CLIENT} -q "DROP USER IF EXISTS u_02377"
${DATASTORE_CLIENT} -q "drop quota if exists q_02377"
