#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

database_name="$DATASTORE_DATABASE"_d1

${DATASTORE_CLIENT} "
CREATE DATABASE IF NOT EXISTS $database_name;

CREATE TABLE IF NOT EXISTS $database_name.t1 (val Int) engine=Memory;
INSERT INTO $database_name.t1 SELECT 1;
"

${DATASTORE_CLIENT} --query="SELECT * FROM t1" 2>&1 | grep -q 'UNKNOWN_TABLE' || echo 'Missing UNKNOWN_TABLE error'

${DATASTORE_CLIENT} "
USE DATABASE $database_name;
SELECT * FROM t1;
"

${DATASTORE_CLIENT} "
DROP TABLE $database_name.t1;
DROP DATABASE $database_name;
"

database_name="$DATASTORE_DATABASE"_database

${DATASTORE_CLIENT} --query="CREATE DATABASE IF NOT EXISTS $database_name"

${DATASTORE_CLIENT} --query="USE DATABASE $database_name"
${DATASTORE_CLIENT} --query="USE $database_name"

${DATASTORE_CLIENT} --query="DROP DATABASE $database_name"
