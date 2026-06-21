#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test"
${DATASTORE_CLIENT} --query "CREATE TABLE test (f1 String, f2 String) ENGINE = Memory"

${DATASTORE_CURL} -vsS "${DATASTORE_URL}" --data-binary 'insert into test (f1, f2) format TSV 1' 2>&1 | grep -F '< HTTP/'

${DATASTORE_CLIENT} --query "DROP TABLE test"
