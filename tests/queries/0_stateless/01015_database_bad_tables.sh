#!/usr/bin/env bash
# Tags: log-engine
CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

db="db_$DATASTORE_DATABASE"
$DATASTORE_CLIENT -q "DROP DATABASE IF EXISTS $db;"
$DATASTORE_CLIENT -q "CREATE DATABASE $db;"
$DATASTORE_CLIENT -q "CREATE TABLE $db.\`таблица_со_странным_названием\` (a UInt64, b UInt64) ENGINE = Log;"
$DATASTORE_CLIENT -q "INSERT INTO $db.\`таблица_со_странным_названием\` VALUES (1, 1);"
$DATASTORE_CLIENT -q "SELECT * FROM $db.\`таблица_со_странным_названием\`;"
$DATASTORE_CLIENT -q "DETACH DATABASE $db;"
$DATASTORE_CLIENT -q "ATTACH DATABASE $db;"
$DATASTORE_CLIENT -q "SELECT * FROM $db.\`таблица_со_странным_названием\`;"
$DATASTORE_CLIENT -q "DROP TABLE $db.\`таблица_со_странным_названием\`;"
$DATASTORE_CLIENT -q "DROP DATABASE $db;"
