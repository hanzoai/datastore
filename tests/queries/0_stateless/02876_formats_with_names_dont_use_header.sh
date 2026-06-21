#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo -e "a,b,c\n1,2,3" > $DATASTORE_TEST_UNIQUE_NAME.csvwithnames

$DATASTORE_LOCAL -q "select b from file('$DATASTORE_TEST_UNIQUE_NAME.csvwithnames') settings input_format_with_names_use_header=0"

rm $DATASTORE_TEST_UNIQUE_NAME.csvwithnames
