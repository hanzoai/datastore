#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user="user03788_$DATASTORE_DATABASE"
db=${DATASTORE_DATABASE}

$DATASTORE_CLIENT -m -q "
DROP TABLE IF EXISTS join_table;
CREATE TABLE join_table (id UInt8, secret String, payload String) ENGINE=Join(ANY, LEFT, id);
INSERT INTO join_table VALUES (1, 'SENSITIVE_DATA', 'payload1');

DROP USER IF EXISTS $user;
CREATE USER $user IDENTIFIED WITH no_password;
"

$DATASTORE_CLIENT --user $user -m -q "SELECT * FROM join_table; -- { serverError ACCESS_DENIED }"
$DATASTORE_CLIENT --user $user -m -q "SELECT joinGet('$db.join_table', 'secret', 1); -- { serverError ACCESS_DENIED }"

$DATASTORE_CLIENT -m -q "GRANT SELECT ON $db.join_table TO $user"

$DATASTORE_CLIENT --user $user -m -q "SELECT * FROM join_table"
$DATASTORE_CLIENT --user $user -m -q "SELECT joinGet('$db.join_table', 'secret', 1)"

$DATASTORE_CLIENT -m -q "REVOKE SELECT(secret) ON $db.join_table FROM $user;"

$DATASTORE_CLIENT --user $user -m -q "SELECT joinGet('$db.join_table', 'secret', 1); -- { serverError ACCESS_DENIED }"
$DATASTORE_CLIENT --user $user -m -q "SELECT secret FROM join_table; -- { serverError ACCESS_DENIED }"
$DATASTORE_CLIENT --user $user -m -q "SELECT joinGet('$db.join_table', 'payload', 1)"
$DATASTORE_CLIENT --user $user -m -q "SELECT payload FROM join_table;"

$DATASTORE_CLIENT -m -q "REVOKE SELECT(id) ON $db.join_table FROM $user;"
$DATASTORE_CLIENT --user $user -m -q "SELECT id FROM join_table; -- { serverError ACCESS_DENIED }"
$DATASTORE_CLIENT --user $user -m -q "SELECT joinGet('$db.join_table', 'payload', 1); -- { serverError ACCESS_DENIED }"


$DATASTORE_CLIENT -m -q "DROP USER $user"
