#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user="user03300_$DATASTORE_DATABASE"
db=${DATASTORE_DATABASE}
db2=${DATASTORE_DATABASE}_2

$DATASTORE_CLIENT -m -q "
CREATE DATABASE IF NOT EXISTS $db2;

DROP USER IF EXISTS $user;
CREATE USER $user;

GRANT ALL ON $db.* TO $user;
GRANT SELECT ON system.databases TO $user;
"

$DATASTORE_CLIENT --user "$user" -m -q "
SELECT DISTINCT name FROM system.databases WHERE database LIKE '$db%' ORDER BY 1
"

$DATASTORE_CLIENT -m -q "
DROP USER $user;
"
