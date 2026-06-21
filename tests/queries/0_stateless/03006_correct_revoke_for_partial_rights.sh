#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

db=${DATASTORE_DATABASE}
user1="user1_03006_${db}_$RANDOM"
user2="user2_03006_${db}_$RANDOM"

${DATASTORE_CLIENT} <<EOF
DROP DATABASE IF EXISTS $db;
CREATE DATABASE $db;
CREATE USER $user1, $user2;

GRANT SELECT ON *.* TO $user2 WITH GRANT OPTION;
REVOKE SELECT ON system.* FROM $user2;
EOF

${DATASTORE_CLIENT} --user $user2 --query "GRANT CURRENT GRANTS ON *.* TO $user1"
${DATASTORE_CLIENT} --user $user2 --query "REVOKE ALL ON *.* FROM $user1"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user1"

${DATASTORE_CLIENT} --user $user2 --query "GRANT CURRENT GRANTS ON *.* TO $user1"
${DATASTORE_CLIENT} --query "REVOKE ALL ON $db.* FROM $user1"
${DATASTORE_CLIENT} --user $user2 --query "REVOKE ALL ON *.* FROM $user1"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user1"

${DATASTORE_CLIENT} --user $user2 --query "GRANT CURRENT GRANTS ON *.* TO $user1"
${DATASTORE_CLIENT} --query "REVOKE ALL ON $db.* FROM $user2"
${DATASTORE_CLIENT} --user $user2 --query "REVOKE ALL ON *.* FROM $user1" 2>&1 | grep -c "ACCESS_DENIED"

${DATASTORE_CLIENT} --query "DROP DATABASE IF EXISTS $db"
