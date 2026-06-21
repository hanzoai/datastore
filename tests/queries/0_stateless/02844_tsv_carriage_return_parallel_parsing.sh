#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select 'Hello\rWorld' from numbers(1000000) format TSVRaw" > $DATASTORE_TEST_UNIQUE_NAME.tsv
$DATASTORE_LOCAL -q "select count() from file('$DATASTORE_TEST_UNIQUE_NAME.tsv')"
rm $DATASTORE_TEST_UNIQUE_NAME.tsv

