#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "
SELECT * FROM url(
    \$\$http://127.0.0.1:${DATASTORE_PORT_HTTP}/?query=SELECT+'{\"a\":1}'\$\$,
    JSONEachRow,
    'a int, b int default 7, c default a + b')
FORMAT Values"
