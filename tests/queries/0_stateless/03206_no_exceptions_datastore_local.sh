#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

DATASTORE_TERMINATE_ON_ANY_EXCEPTION=1 ${DATASTORE_LOCAL} --query "SELECT * FROM table" --input-format CSV <<<"Hello, world"
