#!/usr/bin/env bash

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

[ -e "${DATASTORE_TMP}"/test_squashing_block_without_column.out ] && rm "${DATASTORE_TMP}"/test_squashing_block_without_column.out

${DATASTORE_CLIENT} --query "select number as SomeID, number+1 as OtherID from system.numbers limit 1000 into outfile '${DATASTORE_TMP}/test_squashing_block_without_column.out' format Native"

${DATASTORE_CLIENT} --query "drop table if exists squashed_numbers"
${DATASTORE_CLIENT} --query "create table squashed_numbers (SomeID UInt64, DifferentID UInt64, OtherID UInt64) engine Memory"

#address=${DATASTORE_HOST}
#port=${DATASTORE_PORT_HTTP}
#url="${DATASTORE_PORT_HTTP_PROTO}://$address:$port/"

${DATASTORE_CURL} -sS --data-binary "@${DATASTORE_TMP}/test_squashing_block_without_column.out" "${DATASTORE_URL}&query=insert%20into%20squashed_numbers%20format%20Native"

${DATASTORE_CLIENT} --query "select 'Still alive'"

${DATASTORE_CLIENT} --query "drop table squashed_numbers"
