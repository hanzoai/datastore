#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

echo "SELECT 1 AS a, 2 AS b, 3 AS c, 4 AS d, 5 AS e; SELECT 42" \
    | $DATASTORE_FORMAT -n

echo "SELECT 1 AS a, 2 AS b, 3 AS c, 4 AS d, 5 AS e; SELECT 42" \
    | $DATASTORE_FORMAT -n --semicolons_inline

echo "SELECT 1; SELECT 2" \
    | $DATASTORE_FORMAT -n

echo "SELECT 1; SELECT 2" \
    | $DATASTORE_FORMAT -n --semicolons_inline
