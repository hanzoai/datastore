#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

touch $DATASTORE_TEST_UNIQUE_NAME.unknown
$DATASTORE_LOCAL -q "select * from file('$DATASTORE_TEST_UNIQUE_NAME.u*')" 2>&1 | grep -c "CANNOT_DETECT_FORMAT"
rm $DATASTORE_TEST_UNIQUE_NAME.unknown

touch $DATASTORE_TEST_UNIQUE_NAME.xml
$DATASTORE_LOCAL -q "select * from file('$DATASTORE_TEST_UNIQUE_NAME.x*')" 2>&1 | grep -c "XML file format doesn't support schema inference"
rm $DATASTORE_TEST_UNIQUE_NAME.xml
