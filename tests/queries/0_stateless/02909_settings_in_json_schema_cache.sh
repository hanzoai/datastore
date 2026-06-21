#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo '{"x" : 42}' > $DATASTORE_TEST_UNIQUE_NAME.json
$DATASTORE_LOCAL -m -q "
DESC file('$DATASTORE_TEST_UNIQUE_NAME.json') SETTINGS schema_inference_make_columns_nullable=1;
DESC file('$DATASTORE_TEST_UNIQUE_NAME.json') SETTINGS schema_inference_make_columns_nullable=0;
SELECT count() from system.schema_inference_cache where format = 'JSON' and additional_format_info like '%schema_inference_make_columns_nullable%';"

rm $DATASTORE_TEST_UNIQUE_NAME.json

