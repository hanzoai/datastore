#!/usr/bin/env bash
# Until recently, datastore-local supported only SQL-based named collections configuration,
# but not the static configuration of named collections in the config file.

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

CONFIG_FILE="${DATASTORE_TMP}/config.yaml"

> "${CONFIG_FILE}" echo "
named_collections:
    test:
        hello: 'world'
"

$DATASTORE_LOCAL --config-file "${CONFIG_FILE}" --filesystem_cache_name cache --query "
SELECT * FROM system.named_collections
"

rm "${CONFIG_FILE}"
