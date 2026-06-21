#!/usr/bin/env bash
# shellcheck disable=SC2154

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

alive_host=$DATASTORE_HOST
not_alive_host="255.255.255.255"

DATASTORE_HOST=$not_alive_host $DATASTORE_CLIENT --connect_timeout 1 --query "SELECT 1" |& grep -Fo 'Network is unreachable: 255.255.255.255:9000'
DATASTORE_HOST=$alive_host $DATASTORE_CLIENT --query "SELECT 1"
