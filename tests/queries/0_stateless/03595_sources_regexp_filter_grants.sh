#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user1="user03595_1_${DATASTORE_DATABASE}_$RANDOM"
user2="user03595_2_${DATASTORE_DATABASE}_$RANDOM"

${DATASTORE_CLIENT} <<EOF
-- Cleanup
DROP USER IF EXISTS $user1, $user2;
CREATE USER $user1;
CREATE USER $user2;
GRANT CREATE TEMPORARY TABLE ON *.* TO $user1;
EOF

${DATASTORE_CLIENT} --query "GRANT READ ON URL('http://localhost:812[1-3]/.*') TO $user1 WITH GRANT OPTION";
(( $(${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8124/', LineAsString) FORMAT Null;" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8123/', LineAsString) FORMAT Null;";

echo '--without grants--'
${DATASTORE_CLIENT} --query "REVOKE READ ON URL FROM $user1";
(( $(${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8124/', LineAsString) FORMAT Null;" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
(( $(${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8123/', LineAsString) FORMAT Null;" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo '--multiple grants--'
${DATASTORE_CLIENT} --query "GRANT READ ON URL('http://localhost:912.*') TO $user1";
${DATASTORE_CLIENT} --query "GRANT READ ON URL('http://localhost:812.*') TO $user1";
${DATASTORE_CLIENT} --query "GRANT READ ON S3('http://localhost:11111/.*') TO $user1";
${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8123/', LineAsString) FORMAT Null;";
${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM s3('http://localhost:11111/test/a.tsv', 'TSV') FORMAT Null;";
echo 'OK'

echo '--wrong grant--'
${DATASTORE_CLIENT} --query "REVOKE READ ON URL FROM $user1";
${DATASTORE_CLIENT} --query "GRANT WRITE ON URL('http://localhost:812.*') TO $user1";
(( $(${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8123/', LineAsString) FORMAT Null;" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo '--partial revokes--'
${DATASTORE_CLIENT} --query "REVOKE ALL ON *.* FROM $user1";
${DATASTORE_CLIENT} --query "GRANT READ ON URL('http://localhost:812.*') TO $user1";
${DATASTORE_CLIENT} --query "GRANT CREATE TEMPORARY TABLE ON *.* TO $user1;";
${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8123/', LineAsString) FORMAT Null;";
${DATASTORE_CLIENT} --query "REVOKE READ ON URL('foo.*') FROM $user1";
(( $(${DATASTORE_CLIENT} --user $user1 --query "SELECT * FROM url('http://localhost:8123/', LineAsString) FORMAT Null;" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo '--invalid regexp--'
(( $(${DATASTORE_CLIENT} --user $user1 --query "GRANT READ ON URL('(\w+) \1') TO $user1;" 2>&1 | grep -c "Syntax error") >= 1 )) && echo "OK" || echo "UNEXPECTED"
(( $(${DATASTORE_CLIENT} --user $user1 --query "GRANT READ ON URL('(?Pempty_name)') TO $user1;" 2>&1 | grep -c "Syntax error") >= 1 )) && echo "OK" || echo "UNEXPECTED"


${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user1, $user2;
EOF
