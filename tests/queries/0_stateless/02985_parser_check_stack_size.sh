#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "select 'create table test (x ' || repeat('Array(', 10000) || 'UInt64' || repeat(')', 10000) || ') engine=Memory' format TSVRaw" | $DATASTORE_CURL "${DATASTORE_URL}&max_parser_depth=100000" --data-binary @- | grep -o -F 'TOO_DEEP'
