#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS json_test"

${DATASTORE_CLIENT} --query="CREATE TABLE json_test (id UInt32, metadata String) ENGINE = MergeTree() ORDER BY id"

${DATASTORE_CLIENT} --query="INSERT INTO json_test VALUES (1, '{\"date\": \"2018-01-01\", \"task_id\": \"billing_history__billing_history.load_history_payments_data__20180101\"}'), (2, '{\"date\": \"2018-01-02\", \"task_id\": \"billing_history__billing_history.load_history_payments_data__20180101\"}')"

${DATASTORE_CLIENT} --query="SELECT COUNT() FROM json_test"

${DATASTORE_CLIENT} --query="ALTER TABLE json_test DELETE WHERE JSONExtractString(metadata, 'date') = '2018-01-01'" --mutations_sync=1

${DATASTORE_CLIENT} --query="SELECT COUNT() FROM json_test"

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS json_test"
