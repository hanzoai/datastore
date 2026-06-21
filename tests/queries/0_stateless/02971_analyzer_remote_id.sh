#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query="CREATE TABLE ${DATASTORE_DATABASE}.x ENGINE = MergeTree() ORDER BY number AS SELECT * FROM numbers(2)"
${DATASTORE_LOCAL} --query="SELECT count() FROM remote('127.0.0.{2,3}:${DATASTORE_PORT_TCP}', '${DATASTORE_DATABASE}.x') SETTINGS enable_analyzer = 1" 2>&1 \
        | grep -av "ASan doesn't fully support makecontext/swapcontext functions"
