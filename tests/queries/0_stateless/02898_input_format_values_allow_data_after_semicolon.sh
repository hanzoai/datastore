#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT -q "insert into function null() values (1); -- { foo }"
$DATASTORE_LOCAL  -q "insert into function null() values (1); -- { foo }"
