#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} "
DROP TABLE IF EXISTS test;
CREATE TABLE test (s String) ORDER BY ();
INSERT INTO test VALUES ('Hello, world!');
"

${DATASTORE_LOCAL} "
CREATE NAMED COLLECTION mydb AS host = '${DATASTORE_HOST}', port = ${DATASTORE_PORT_TCP}, user = 'default', password = '', db = '${DATASTORE_DATABASE}';
SELECT * FROM remote(mydb, table = 'test');
" 2>&1 | grep --text -F -v "ASan doesn't fully support makecontext/swapcontext functions"

${DATASTORE_CLIENT} "
DROP TABLE test;
"
