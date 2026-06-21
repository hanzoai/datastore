#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT --query "
CREATE TABLE ${DATASTORE_DATABASE}.table_for_dict
(
  key_column UInt64,
  value Float64
)
ENGINE = MergeTree()
ORDER BY key_column"

$DATASTORE_CLIENT --query "INSERT INTO ${DATASTORE_DATABASE}.table_for_dict VALUES (1, 1.1)"

$DATASTORE_CLIENT --query "
CREATE DICTIONARY ${DATASTORE_DATABASE}.dict_with_zero_min_lifetime
(
    key_column UInt64,
    value Float64 DEFAULT 77.77
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict' DB '${DATASTORE_DATABASE}'))
LIFETIME(1)
LAYOUT(FLAT())"

$DATASTORE_CLIENT --query "SELECT dictGetFloat64('${DATASTORE_DATABASE}.dict_with_zero_min_lifetime', 'value', toUInt64(1))"

$DATASTORE_CLIENT --query "SELECT dictGetFloat64('${DATASTORE_DATABASE}.dict_with_zero_min_lifetime', 'value', toUInt64(2))"

$DATASTORE_CLIENT --query "INSERT INTO ${DATASTORE_DATABASE}.table_for_dict VALUES (2, 2.2)"


function check()
{
    # The background reload thread (PeriodicUpdater) wakes up every 5 seconds regardless of LIFETIME,
    # so allow enough time for several check cycles plus the reload itself.
    local TIMELIMIT=$((SECONDS+30))
    query_result=$($DATASTORE_CLIENT --query "SELECT dictGetFloat64('${DATASTORE_DATABASE}.dict_with_zero_min_lifetime', 'value', toUInt64(2))")

    while [ "$query_result" != "2.2" ] && [ $SECONDS -lt "$TIMELIMIT" ]
    do
        sleep 0.2
        query_result=$($DATASTORE_CLIENT --query "SELECT dictGetFloat64('${DATASTORE_DATABASE}.dict_with_zero_min_lifetime', 'value', toUInt64(2))")
    done
}

check

$DATASTORE_CLIENT --query "SELECT dictGetFloat64('${DATASTORE_DATABASE}.dict_with_zero_min_lifetime', 'value', toUInt64(1))"

$DATASTORE_CLIENT --query "SELECT dictGetFloat64('${DATASTORE_DATABASE}.dict_with_zero_min_lifetime', 'value', toUInt64(2))"
