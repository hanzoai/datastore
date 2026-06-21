#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo 'DROP TABLE IF EXISTS long_insert' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'CREATE TABLE long_insert (str String) ENGINE = Memory' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
for string_size in 1 10 100 1000 10000 100000 1000000; do
    # LC_ALL=C is needed because otherwise Perl will bark on bad tuned environment.
    LC_ALL=C perl -we 'for my $letter ("a" .. "z") { print(($letter x '$string_size') . "\n") }' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}&query=INSERT+INTO+long_insert+FORMAT+TabSeparated" --data-binary @-
    echo 'SELECT substring(str, 1, 1) AS c, length(str) AS l FROM long_insert ORDER BY c, l' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
done

echo 'DROP TABLE long_insert' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
