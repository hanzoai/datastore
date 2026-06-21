#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

{ printf "select "; for _ in {1..1000}; do printf "coalesce(null, "; done; printf "1"; for _ in {1..1000}; do printf ")"; done; } > "${DATASTORE_TMP}"/query

echo '-- 1.'
cat "${DATASTORE_TMP}"/query | $DATASTORE_CLIENT 2>&1 | grep -o -m1 -F 'Code: 167'
echo '-- 2.'
cat "${DATASTORE_TMP}"/query | $DATASTORE_LOCAL 2>&1 | grep -o -m1 -F 'Code: 167'
echo '-- 3.'
cat "${DATASTORE_TMP}"/query | $DATASTORE_CURL --data-binary @- -vsS "$DATASTORE_URL" 2>&1 | grep -o -m1 -F 'Code: 167'
