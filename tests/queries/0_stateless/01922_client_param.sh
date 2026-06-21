#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT --param_foo |& grep -q -x 'Code: 36. DB::Exception: Parameter requires value'
$DATASTORE_CLIENT --param_foo foo -q 'select {foo:String}'
$DATASTORE_CLIENT -q 'select {foo:String}' --param_foo foo
