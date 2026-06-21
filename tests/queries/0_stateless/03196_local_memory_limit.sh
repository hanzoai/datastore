#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_LOCAL} --config-file <(echo "<datastore><max_server_memory_usage>100M</max_server_memory_usage></datastore>") --query "SELECT number FROM system.numbers GROUP BY number HAVING count() > 1 SETTINGS max_bytes_ratio_before_external_group_by = 0" 2>&1 | grep -o -P 'maximum: [\d\.]+ MiB'
