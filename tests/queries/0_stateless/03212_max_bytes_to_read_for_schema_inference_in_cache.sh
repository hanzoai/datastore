#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

echo '{"x" : 42}' > $DATASTORE_TEST_UNIQUE_NAME.json
$DATASTORE_LOCAL -m -q "
DESC file('$DATASTORE_TEST_UNIQUE_NAME.json') SETTINGS input_format_max_bytes_to_read_for_schema_inference=1000; 
SELECT additional_format_info from system.schema_inference_cache"

rm $DATASTORE_TEST_UNIQUE_NAME.json

