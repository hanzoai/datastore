#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CURL -sS "$DATASTORE_URL" -d "DROP TABLE IF EXISTS enum";
$DATASTORE_CURL -sS "$DATASTORE_URL" -d "CREATE TABLE enum (x Enum8('a' = 1, 'bcdefghijklmno' = 0)) ENGINE = Memory";
$DATASTORE_CURL -sS "$DATASTORE_URL" -d "INSERT INTO enum VALUES ('a')";
$DATASTORE_CURL -sS "$DATASTORE_URL" -d "SELECT * FROM enum";
$DATASTORE_CURL -sS "$DATASTORE_URL" -d "DROP TABLE enum";
