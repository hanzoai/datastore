#!/usr/bin/env bash
# Tags: no-random-settings

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

FILE=${DATASTORE_TMP}/${DATASTORE_DATABASE}_without_extension
echo "SELECT 'Hello from a file'" > ${FILE}

# Queries can be read from a file.
${DATASTORE_BINARY} --queries-file ${FILE}

# Or from stdin.
${DATASTORE_BINARY} < ${FILE}

# Also the positional argument can be interpreted as a file.
${DATASTORE_BINARY} ${FILE}

${DATASTORE_LOCAL} --queries-file ${FILE}
${DATASTORE_LOCAL} < ${FILE}
${DATASTORE_LOCAL} ${FILE}

${DATASTORE_CLIENT} --queries-file ${FILE}
${DATASTORE_CLIENT} < ${FILE}
${DATASTORE_CLIENT} ${FILE}

# Check that positional arguments work in any place
echo "Select name, changed, value FROM system.settings where name = 'max_local_read_bandwidth'" > ${FILE}
${DATASTORE_BINARY} ${FILE} --max-local-read-bandwidth 100
${DATASTORE_BINARY} --max-local-read-bandwidth 200 ${FILE}

rm ${FILE}
