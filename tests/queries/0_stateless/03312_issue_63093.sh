#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --param-test "param-test OK" -q "SELECT {test:String}"
${DATASTORE_CLIENT} --param_test "param_test OK" -q "SELECT {test:String}"
