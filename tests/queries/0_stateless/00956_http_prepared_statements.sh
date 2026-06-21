#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CURL} -sS "$DATASTORE_URL" -d "DROP TABLE IF EXISTS ps";
${DATASTORE_CURL} -sS "$DATASTORE_URL" -d "CREATE TABLE ps (i UInt8, s String, d Date) ENGINE = Memory";

${DATASTORE_CURL} -sS "$DATASTORE_URL" -d "INSERT INTO ps VALUES (1, 'Hello, world', '2005-05-05')";
${DATASTORE_CURL} -sS "$DATASTORE_URL" -d "INSERT INTO ps VALUES (2, 'test', '2019-05-25')";

${DATASTORE_CURL} -sS "${DATASTORE_URL}&param_id=1" \
    -d "SELECT * FROM ps WHERE i = {id:UInt8} ORDER BY i, s, d";
${DATASTORE_CURL} -sS "${DATASTORE_URL}&param_phrase=Hello,+world" \
    -d "SELECT * FROM ps WHERE s = {phrase:String} ORDER BY i, s, d";
${DATASTORE_CURL} -sS "${DATASTORE_URL}&param_date=2019-05-25" \
    -d "SELECT * FROM ps WHERE d = {date:Date} ORDER BY i, s, d";
${DATASTORE_CURL} -sS "${DATASTORE_URL}&param_id=2&param_phrase=test" \
    -d "SELECT * FROM ps WHERE i = {id:UInt8} and s = {phrase:String} ORDER BY i, s, d";

${DATASTORE_CURL} -sS "$DATASTORE_URL" -d "DROP TABLE ps";
