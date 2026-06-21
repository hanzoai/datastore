#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT --pager 'wc -c' --query 'select 123'
$DATASTORE_LOCAL  --pager 'wc -c' --query 'select 123'
