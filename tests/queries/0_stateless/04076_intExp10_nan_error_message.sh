#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "SELECT intExp10(nan)" 2>&1 | grep -q 'intExp10 must not be called with nan' && echo "OK" || echo "FAIL"
