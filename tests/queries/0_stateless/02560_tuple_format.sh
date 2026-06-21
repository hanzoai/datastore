#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo "select (tuple(1, 2, 3));" | "$DATASTORE_FORMAT"
echo "select (tuple(1, 2, 3) as x);" | "$DATASTORE_FORMAT"
echo "select (tuple(1, 2, 3)).1;" | "$DATASTORE_FORMAT"
echo "select (tuple(1, 2, 3) as x).1;" | "$DATASTORE_FORMAT"
