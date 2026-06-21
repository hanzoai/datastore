#!/usr/bin/env bash
# Tags: no-replicated-database

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user="user04010_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user;
CREATE USER $user;
CREATE TABLE $db.secret_table (x UInt32, secret String) ENGINE = MergeTree ORDER BY x;
GRANT CREATE TEMPORARY TABLE ON *.* TO $user;
EOF

${DATASTORE_CLIENT} --user $user --query "DESCRIBE $db.secret_table; -- { serverError ACCESS_DENIED }"
${DATASTORE_CLIENT} --user $user --query "DESCRIBE remote('127.0.0.1:${DATASTORE_PORT_TCP}', '$db', 'secret_table'); -- { serverError ACCESS_DENIED }"
${DATASTORE_CLIENT} --user $user --query "DESCRIBE clusterAllReplicas('test_shard_localhost', '$db', 'secret_table'); -- { serverError ACCESS_DENIED }"

${DATASTORE_CLIENT} --query "GRANT SHOW COLUMNS ON $db.secret_table TO $user"
${DATASTORE_CLIENT} --query "GRANT READ ON REMOTE TO $user"

${DATASTORE_CLIENT} --user $user --query "DESCRIBE $db.secret_table" | cut -f1
${DATASTORE_CLIENT} --user $user --query "DESCRIBE remote('127.0.0.1:${DATASTORE_PORT_TCP}', '$db', 'secret_table')" | cut -f1
${DATASTORE_CLIENT} --user $user --query "DESCRIBE clusterAllReplicas('test_shard_localhost', '$db', 'secret_table')" | cut -f1

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user;
DROP TABLE IF EXISTS $db.secret_table;
EOF
