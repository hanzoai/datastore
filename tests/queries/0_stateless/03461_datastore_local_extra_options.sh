#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_LOCAL} --query "SELECT getServerSetting('max_connections')" -- --max_connections=666
${DATASTORE_LOCAL} --query "SELECT getServerSetting('max_connections')" -- --max_connections 666
