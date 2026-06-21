#!/usr/bin/env bash
# Tags: no-replicated-database

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
GRANT CREATE TEMPORARY TABLE ON *.* TO $user;
EOF

${DATASTORE_CLIENT} --user $user --query "SELECT * FROM loop('$db', 'test_table') LIMIT 1; -- { serverError ACCESS_DENIED }";
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_table TO $user";
${DATASTORE_CLIENT} --user $user --query "SELECT * FROM loop('$db', 'test_table') LIMIT 1";

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user";
