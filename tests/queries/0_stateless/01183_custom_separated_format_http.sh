#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo 'DROP TABLE IF EXISTS mydb' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'CREATE TABLE mydb (datetime String, d1 String, d2 String ) ENGINE=Memory' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo "2021-Jan^d1^d2" | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}&query=INSERT%20INTO%20mydb%20SETTINGS%20format_custom_escaping_rule%3D%27CSV%27%2C%20format_custom_field_delimiter%20%3D%20%27%5E%27%20FORMAT%20CustomSeparated" --data-binary @-
echo -n "" | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}&query=INSERT%20INTO%20mydb%20SETTINGS%20format_custom_escaping_rule%3D%27CSV%27%2C%20format_custom_field_delimiter%20%3D%20%27%5E%27%20FORMAT%20CustomSeparated" --data-binary @-
echo 'SELECT * FROM mydb' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
printf "2021-Jan^d1^d2\n%.0s" {1..999999} | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}&query=INSERT%20INTO%20mydb%20SETTINGS%20format_custom_escaping_rule%3D%27CSV%27%2C%20format_custom_field_delimiter%20%3D%20%27%5E%27%20FORMAT%20CustomSeparated" --data-binary @-
echo 'SELECT count(*), countDistinct(datetime, d1, d2) FROM mydb' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
echo 'DROP TABLE mydb' | ${DATASTORE_CURL} -sSg "${DATASTORE_URL}" -d @-
