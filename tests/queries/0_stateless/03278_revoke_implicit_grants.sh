#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user="user03278_${DATASTORE_DATABASE}_$RANDOM"
role1="role03278_1_${DATASTORE_DATABASE}_$RANDOM"
role2="role03278_2_${DATASTORE_DATABASE}_$RANDOM"


${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user;";

${DATASTORE_CLIENT} <<EOF
CREATE USER $user;
CREATE ROLE $role1, $role2;

GRANT SELECT ON *.* TO $role1 WITH GRANT OPTION;
REVOKE SELECT ON test.table FROM $role1;

GRANT SELECT ON *.* TO $role2 WITH GRANT OPTION;
REVOKE SELECT ON test.table FROM $role2;
GRANT SHOW TABLES ON default.* TO $role2;

GRANT $role1 TO $user;
EOF

${DATASTORE_CLIENT} --user $user --query "REVOKE ALL ON *.* FROM $role2"
${DATASTORE_CLIENT} --query "SHOW GRANTS FOR $role2"
