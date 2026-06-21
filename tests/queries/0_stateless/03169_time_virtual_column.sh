#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo "1,2" > $DATASTORE_TEST_UNIQUE_NAME.csv
sleep 1
$DATASTORE_LOCAL -m -q "
select _size, (dateDiff('millisecond', _time, now()) < 600000 AND dateDiff('millisecond', _time, now()) > 0) from file('$DATASTORE_TEST_UNIQUE_NAME.csv');
"
rm $DATASTORE_TEST_UNIQUE_NAME.csv
