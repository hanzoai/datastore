#!/usr/bin/env bash
# Tags: no-replicated-database
# Tag no-replicated-database: Requires investigation

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

URL="${DATASTORE_URL}&session_id=id_${DATASTORE_DATABASE}"

echo "DROP TABLE IF EXISTS table" | ${DATASTORE_CURL} -sSg "${URL}" -d @-
echo "CREATE TABLE table (a String) ENGINE Memory()" | ${DATASTORE_CURL} -sSg "${URL}" -d @-

# NOTE: suppose that curl sends everything in a single chunk - there are no options to force the chunk-size.
echo "SET max_query_size=44" | ${DATASTORE_CURL} -sSg "${URL}" -d @-
echo -ne "INSERT INTO TABLE table FORMAT TabSeparated 1234567890 1234567890 1234567890 1234567890\n" | ${DATASTORE_CURL} -H "Transfer-Encoding: chunked" -sS "${URL}" --data-binary @-

echo "SELECT * from table" | ${DATASTORE_CURL} -sSg "${URL}" -d @-
echo "DROP TABLE table" | ${DATASTORE_CURL} -sSg "${URL}" -d @-
