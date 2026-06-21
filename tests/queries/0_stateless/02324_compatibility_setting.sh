#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo "allow_settings_after_format_in_insert"
echo "22.3"
$DATASTORE_CLIENT --compatibility=22.3 -q "select value from system.settings where name='allow_settings_after_format_in_insert'"
${DATASTORE_CURL} -sS "${DATASTORE_URL}&compatibility=22.3" -d "select value from system.settings where name='allow_settings_after_format_in_insert'"
echo "22.4"
$DATASTORE_CLIENT --compatibility=22.4 -q "select value from system.settings where name='allow_settings_after_format_in_insert'"
echo "22.5"
$DATASTORE_CLIENT --compatibility=22.5 -q "select value from system.settings where name='allow_settings_after_format_in_insert'"


echo "async_socket_for_remote"
echo "21.2"
$DATASTORE_CLIENT --compatibility=21.2 -q "select value from system.settings where name='async_socket_for_remote'"
echo "21.3"
$DATASTORE_CLIENT --compatibility=21.3 -q "select value from system.settings where name='async_socket_for_remote'"
echo "21.4"
$DATASTORE_CLIENT --compatibility=21.4 -q "select value from system.settings where name='async_socket_for_remote'"
echo "21.5"
$DATASTORE_CLIENT --compatibility=21.5 -q "select value from system.settings where name='async_socket_for_remote'"
echo "21.6"
$DATASTORE_CLIENT --compatibility=21.6 -q "select value from system.settings where name='async_socket_for_remote'"

echo "use_concurrency_control"
echo "23.3"
$DATASTORE_CLIENT --compatibility=23.3 -q "select value from system.settings where name='use_concurrency_control'"
echo "24.10"
$DATASTORE_CLIENT --compatibility=24.10 -q "select value from system.settings where name='use_concurrency_control'"
echo "24.12"
$DATASTORE_CLIENT --compatibility=24.12 -q "select value from system.settings where name='use_concurrency_control'"
