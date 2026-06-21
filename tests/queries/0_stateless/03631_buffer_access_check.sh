#!/usr/bin/env bash
# Tags: long, no-replicated-database, no-async-insert

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


user="user03631_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
CREATE TABLE $db.test_table (s String) ENGINE = MergeTree ORDER BY s;
INSERT INTO $db.test_table VALUES ('foo');

DROP USER IF EXISTS $user;
CREATE USER $user;
GRANT SELECT, CREATE, INSERT ON $db.test_buffer TO $user;
GRANT TABLE ENGINE ON Buffer TO $user;
EOF

${DATASTORE_CLIENT} --user $user --query "CREATE TABLE $db.test_buffer ENGINE = Buffer($db, test_table, 1, 10, 100, 10000, 1000000, 10000000, 100000000)"
(( $(${DATASTORE_CLIENT} --user $user --query "SELECT * FROM $db.test_buffer" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
(( $(${DATASTORE_CLIENT} --user $user --query "INSERT INTO $db.test_buffer VALUES ('bar')" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_table TO $user"
${DATASTORE_CLIENT} --user $user --query "SELECT * FROM $db.test_buffer"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user"
