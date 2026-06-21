#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user="user03247_${DATASTORE_DATABASE}_$RANDOM"
role1="role03247_1_${DATASTORE_DATABASE}_$RANDOM"
role2="role03247_2_${DATASTORE_DATABASE}_$RANDOM"


${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user;";
${DATASTORE_CLIENT} --query "CREATE USER $user;";

echo "Empty grants";
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user WITH IMPLICIT;" | sed 's/ TO.*//';

echo "Revoke grants";
${DATASTORE_CLIENT} --query "GRANT SELECT ON *.* TO $user;";
${DATASTORE_CLIENT} --query "REVOKE SELECT ON test_03247.table FROM $user;";
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user WITH IMPLICIT;" | sed 's/ TO.*//' | sed 's/ FROM.*//';

(( $(${DATASTORE_CLIENT} --user $user --query "EXISTS test_03247.table;" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED";
${DATASTORE_CLIENT} --query "EXISTS test_03247.table2;" --user $user;


echo "Show final";
${DATASTORE_CLIENT} --query "DROP ROLE IF EXISTS $role1, $role2;";
${DATASTORE_CLIENT} --query "REVOKE ALL ON *.* FROM $user;";

${DATASTORE_CLIENT} --query "CREATE ROLE $role1;";
${DATASTORE_CLIENT} --query "GRANT SELECT ON *.* TO $role1;";
${DATASTORE_CLIENT} --query "CREATE ROLE $role2;";
${DATASTORE_CLIENT} --query "GRANT $role1 TO $role2;";
${DATASTORE_CLIENT} --query "GRANT $role2 TO $user;";
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user FINAL;" | sed 's/ TO.*//'

echo "Show final with implicit";
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $user FINAL WITH IMPLICIT;" | sed 's/ TO.*//'

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user;";
${DATASTORE_CLIENT} --query "DROP ROLE IF EXISTS $role1, $role2;";
