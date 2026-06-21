#!/usr/bin/env bash

set -eu

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

mkdir -p ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS file_log;"

${DATASTORE_CLIENT} --query "CREATE TABLE file_log  (key UInt8, value UInt8) ENGINE = FileLog('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}', 'JSONEachRow') SETTINGS handle_error_mode = 'stream'"

# send_logs_level: reading from empty file log produces warning
${DATASTORE_CLIENT} --stream_like_engine_allow_direct_select=1 --query "select * from merge('', 'file_log') SETTINGS send_logs_level='error';"
