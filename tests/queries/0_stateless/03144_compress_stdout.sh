#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

[ -e "${DATASTORE_TMP}"/test_compression_of_output_file_from_client.gz ] && rm "${DATASTORE_TMP}"/test_compression_of_output_file_from_client.gz

${DATASTORE_CLIENT} --query "SELECT * FROM (SELECT 'Hello, World! From client.')" > ${DATASTORE_TMP}/test_compression_of_output_file_from_client.gz
gunzip ${DATASTORE_TMP}/test_compression_of_output_file_from_client.gz
cat ${DATASTORE_TMP}/test_compression_of_output_file_from_client

rm -f "${DATASTORE_TMP}/test_compression_of_output_file_from_client"

[ -e "${DATASTORE_TMP}"/test_compression_of_output_file_from_local.gz ] && rm "${DATASTORE_TMP}"/test_compression_of_output_file_from_local.gz

${DATASTORE_LOCAL} --query "SELECT * FROM (SELECT 'Hello, World! From local.')" > ${DATASTORE_TMP}/test_compression_of_output_file_from_local.gz
gunzip ${DATASTORE_TMP}/test_compression_of_output_file_from_local.gz
cat ${DATASTORE_TMP}/test_compression_of_output_file_from_local

rm -f "${DATASTORE_TMP}/test_compression_of_output_file_from_local"
