#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS format"
$DATASTORE_CLIENT --query="CREATE TABLE format (s String, x FixedString(3)) ENGINE = Memory"

echo -ne '\tABC\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}&query=INSERT+INTO+format+FORMAT+TabSeparated" --data-binary @-
echo -ne 'INSERT INTO format FORMAT TabSeparated\n\tDEF\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo -ne 'INSERT INTO format FORMAT TabSeparated hello\tGHI\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo -ne 'INSERT INTO format FORMAT TabSeparated\r\n\tJKL\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo -ne 'INSERT INTO format FORMAT TabSeparated   \t\r\n\tMNO\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-
echo -ne 'INSERT INTO format FORMAT TabSeparated\t\t\thello\tPQR\n' | ${DATASTORE_CURL} -sS "${DATASTORE_URL}" --data-binary @-

$DATASTORE_CLIENT --query="SELECT * FROM format ORDER BY s, x FORMAT JSONEachRow"
$DATASTORE_CLIENT --query="DROP TABLE format"
