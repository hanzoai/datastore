#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_LOCAL} "
CREATE TABLE test (s String, CONSTRAINT s CHECK length(s) < 10) ENGINE = Memory;
INSERT INTO test VALUES ('Hello');
INSERT INTO test VALUES ('World World World World World World World World World World World World World World World World World World World World World World World World World World World World World World World World ');
" 2>&1 | grep -o 'Wor…'
