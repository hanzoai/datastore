#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo '{"x" : [1, "Hello"]}' > $DATASTORE_TEST_UNIQUE_NAME.json
$DATASTORE_LOCAL -m -q "
DESC file('$DATASTORE_TEST_UNIQUE_NAME.json') SETTINGS input_format_try_infer_variants=0;
DESC file('$DATASTORE_TEST_UNIQUE_NAME.json') SETTINGS input_format_try_infer_variants=1;
SELECT additional_format_info from system.schema_inference_cache ORDER BY ALL"

rm $DATASTORE_TEST_UNIQUE_NAME.json

