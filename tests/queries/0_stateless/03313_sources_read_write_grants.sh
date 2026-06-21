#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


user="user03313_${DATASTORE_DATABASE}_$RANDOM"
file="data_${DATASTORE_DATABASE}_$RANDOM.csv"

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user;
CREATE USER $user;
GRANT SELECT, INSERT, CREATE ON *.* TO $user;
EOF

(( $(${DATASTORE_CLIENT} --user $user --query "INSERT INTO FUNCTION file('$file') SELECT 'a', 'b'" 2>&1 | grep -c "grant WRITE ON FILE") >= 1 )) && echo "ACCESS DENIED" || echo "UNEXPECTED";

${DATASTORE_CLIENT} --query "GRANT WRITE ON FILE TO $user";
${DATASTORE_CLIENT} --user $user --query "INSERT INTO FUNCTION file('$file') SELECT 'a', 'b'";

(( $(${DATASTORE_CLIENT} --user $user --query "SELECT count() FROM file('$file')" 2>&1 | grep -c "grant READ ON FILE") >= 1 )) && echo "ACCESS DENIED" || echo "UNEXPECTED";

${DATASTORE_CLIENT} --query "GRANT SOURCE READ ON FILE TO $user";
${DATASTORE_CLIENT} --user $user --query "SELECT count() FROM file('$file')";

${DATASTORE_CLIENT} --query "REVOKE READ, WRITE ON FILE FROM $user";
${DATASTORE_CLIENT} --query "GRANT READ, WRITE ON File TO $user";
${DATASTORE_CLIENT} --user $user --query "INSERT INTO FUNCTION file('$file') SELECT 'a', 'b'";
${DATASTORE_CLIENT} --user $user --query "SELECT count() FROM file('$file')";

${DATASTORE_CLIENT} --query "REVOKE READ, WRITE ON FILE FROM $user";
${DATASTORE_CLIENT} --query "GRANT FILE ON *.* TO $user";
${DATASTORE_CLIENT} --user $user --query "INSERT INTO FUNCTION file('$file') SELECT 'a', 'b'";
${DATASTORE_CLIENT} --user $user --query "SELECT count() FROM file('$file')";

${DATASTORE_CLIENT} --query "REVOKE FILE ON system.* FROM $user";
${DATASTORE_CLIENT} --user $user --query "SELECT count() FROM file('$file')";

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user;";
