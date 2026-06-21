#!/usr/bin/env bash
# Tags: no-random-settings

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# reset --log_comment, because the test has to use the readonly mode
DATASTORE_LOG_COMMENT=
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -m -q "select value, changed from system.settings where name='readonly';"
$DATASTORE_CLIENT -m -q "set profile='default'; select value, changed from system.settings where name='readonly';"
$DATASTORE_CLIENT -m -q "set profile='readonly'; select value, changed from system.settings where name='readonly';" 2>&1| grep -Fa "Cannot modify 'send_logs_level' setting in readonly mode" > /dev/null && echo "OK"
DATASTORE_CLIENT=$(echo ${DATASTORE_CLIENT} | sed 's/'"--send_logs_level=${DATASTORE_CLIENT_SERVER_LOGS_LEVEL}"'/--send_logs_level=fatal/g')
$DATASTORE_CLIENT -m -q "set profile='readonly'; select value, changed from system.settings where name='readonly';"

${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=select+value,changed+from+system.settings+where+name='readonly'"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&profile=default&query=select+value,changed+from+system.settings+where+name='readonly'"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&profile=readonly&query=select+value,changed+from+system.settings+where+name='readonly'" 2>&1 | grep -Fa "Cannot modify 'readonly' setting in readonly mode" > /dev/null && echo "OK"
echo "select value, changed from system.settings where name='readonly';" | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}&profile=readonly" -d @-
