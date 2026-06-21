#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

[ -e "${DATASTORE_TMP}"/test_append_to_output_file ] && rm "${DATASTORE_TMP}"/test_append_to_output_file

${DATASTORE_CLIENT} --query "SELECT * FROM (SELECT 'Hello, World! From client.') INTO OUTFILE '${DATASTORE_TMP}/test_append_to_output_file'"
${DATASTORE_LOCAL} --query "SELECT * FROM (SELECT 'Hello, World! From local.') INTO OUTFILE '${DATASTORE_TMP}/test_append_to_output_file' APPEND"
cat ${DATASTORE_TMP}/test_append_to_output_file

rm -f "${DATASTORE_TMP}/test_append_to_output_file"
