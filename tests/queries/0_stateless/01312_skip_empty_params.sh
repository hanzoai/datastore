#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

$DATASTORE_CURL -sS "$DATASTORE_URL&query=select%201&log_queries=1"
$DATASTORE_CURL -sS "$DATASTORE_URL&&query=select%201&log_queries=1"
$DATASTORE_CURL -sS "$DATASTORE_URL&query=select%201&&&log_queries=1"
