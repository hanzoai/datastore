#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -- --default_database='' |& grep -o "default_database cannot be empty. (BAD_ARGUMENTS)"
