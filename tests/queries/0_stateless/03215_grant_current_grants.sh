#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


user1="user03215_1_${DATASTORE_DATABASE}_$RANDOM"
user2="user03215_2_${DATASTORE_DATABASE}_$RANDOM"
user3="user03215_3_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}


${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user1, $user2, $user3";
${DATASTORE_CLIENT} --query "CREATE USER $user1, $user2, $user3;";
${DATASTORE_CLIENT} --query "GRANT SELECT, CREATE TABLE, CREATE VIEW ON $db.* TO $user1 WITH GRANT OPTION;";

${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS ON $db.* TO $user2" --user $user1;
${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS ON $db.* TO $user3" --user $user2;

${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user2" | sed 's/ TO.*//';
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user3" | sed 's/ TO.*//';

${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS(SELECT ON $db.*) TO $user3" --user $user1;
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user3" | sed 's/ TO.*//';

${DATASTORE_CLIENT} --query "REVOKE ALL ON *.* FROM $user1";
${DATASTORE_CLIENT} --query "REVOKE ALL ON *.* FROM $user2";

${DATASTORE_CLIENT} --query "GRANT SELECT ON *.* TO $user1 WITH GRANT OPTION";
${DATASTORE_CLIENT} --query "REVOKE SELECT ON system.zookeeper FROM $user1";

(( $(${DATASTORE_CLIENT} --user $user1 --query "GRANT SELECT ON *.* TO $user2" 2>&1 | grep -c "(Missing permissions: SELECT ON system.*)") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS(SELECT ON *.*) TO $user2" --user $user1;
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user2" | sed 's/ TO.*//' | sed 's/ FROM.*//';

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user1, $user2, $user3";
