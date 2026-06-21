#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "
DROP TABLE IF EXISTS t;
CREATE TABLE t (a String, b String) ENGINE = Memory;
"

${DATASTORE_CLIENT} --format_regexp_escaping_rule 'Raw' --format_regexp '^(.+?) separator (.+?)$' --query '
INSERT INTO t FORMAT Regexp abc\ separator Hello, world!'

${DATASTORE_CLIENT} --query "
SELECT * FROM t;
DROP TABLE t;
"
