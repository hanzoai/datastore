#!/usr/bin/env bash
# Tags: no-replicated-database, no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


user1="user03247_1_${DATASTORE_DATABASE}_$RANDOM"
user2="user03247_2_${DATASTORE_DATABASE}_$RANDOM"
user3="user03247_3_${DATASTORE_DATABASE}_$RANDOM"
user4="user03247_4_${DATASTORE_DATABASE}_$RANDOM"

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user1, $user2, $user3;
CREATE USER $user1;
GRANT CREATE USER ON user03247* TO $user1;
EOF

${DATASTORE_CLIENT} --user $user1 --query "CREATE USER $user2"
${DATASTORE_CLIENT} --user $user1 --query "CREATE USER $user3"
(( $(${DATASTORE_CLIENT} --user $user1 --query "CREATE USER foobar" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "Not enough privileges" || echo "UNEXPECTED"

${DATASTORE_CLIENT} --query "GRANT ALTER USER ON $user2 TO $user2"
(( $(${DATASTORE_CLIENT} --user $user2 --query "ALTER USER $user3 IDENTIFIED BY 'bar'" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "Not enough privileges" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --user $user2 --query "ALTER USER $user2 IDENTIFIED BY 'bar'"
(( $(${DATASTORE_CLIENT} --user $user3 --query "ALTER USER $user2 IDENTIFIED BY 'bar'" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "Not enough privileges" || echo "UNEXPECTED"

${DATASTORE_CLIENT} --query "GRANT ALTER USER ON * TO $user3"
${DATASTORE_CLIENT} --user $user3 --query "ALTER USER $user3 RENAME TO $user4"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user1, $user2, $user3, $user4;"
