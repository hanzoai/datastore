#!/usr/bin/env bash

set -e

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# NOTE: database = $DATASTORE_DATABASE is unwanted
${DATASTORE_CLIENT} --query "CREATE TABLE system.columns AS numbers(10);" 2>&1 | grep -F "Code: 57" > /dev/null && echo 'OK' || echo 'FAIL'
${DATASTORE_CLIENT} --query "CREATE TABLE system.columns engine=Memory AS numbers(10);" 2>&1 | grep -F "Code: 62" > /dev/null && echo 'OK' || echo 'FAIL'
${DATASTORE_CLIENT} --query "CREATE TABLE system.columns AS numbers(10) engine=Memory;" 2>&1 | grep -F "Code: 62" > /dev/null && echo 'OK' || echo 'FAIL'
