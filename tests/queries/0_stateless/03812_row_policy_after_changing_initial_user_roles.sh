#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user_name="user_${DATASTORE_DATABASE}"
role_a="role_a_${DATASTORE_DATABASE}"
role_b="role_b_${DATASTORE_DATABASE}"
row_policy_a="policy_a_${DATASTORE_DATABASE}"
row_policy_b="policy_b_${DATASTORE_DATABASE}"

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS test"
$DATASTORE_CLIENT -q "DROP USER IF EXISTS ${user_name}"
$DATASTORE_CLIENT -q "DROP ROLE IF EXISTS ${role_a}, ${role_b}"
$DATASTORE_CLIENT -q "DROP ROW POLICY IF EXISTS ${row_policy_a}, ${row_policy_b} ON test"

$DATASTORE_CLIENT -q "CREATE TABLE test(x Int64) ENGINE=Memory"
$DATASTORE_CLIENT -q "INSERT INTO test SELECT number FROM numbers(10)"

$DATASTORE_CLIENT -q "CREATE USER ${user_name}"

$DATASTORE_CLIENT -q "CREATE ROLE ${role_a}"
$DATASTORE_CLIENT -q "GRANT SELECT ON test, REMOTE ON *.* TO ${role_a}"
$DATASTORE_CLIENT -q "CREATE ROW POLICY ${row_policy_a} ON test FOR SELECT USING x % 2 = 0 TO ${role_a}"

$DATASTORE_CLIENT -q "CREATE ROLE ${role_b}"
$DATASTORE_CLIENT -q "GRANT SELECT ON test, REMOTE ON *.* TO ${role_b}"
$DATASTORE_CLIENT -q "CREATE ROW POLICY ${row_policy_b} ON test FOR SELECT USING x % 2 = 1 TO ${role_b}"

echo 'with row policy a:'
$DATASTORE_CLIENT -q "GRANT ${role_a} TO ${user_name}"
$DATASTORE_CLIENT --user ${user_name} -q "SELECT * FROM cluster('test_shard_localhost', currentDatabase(), test)"
$DATASTORE_CLIENT -q "REVOKE ${role_a} FROM ${user_name}"

echo 'with row policy b:'
$DATASTORE_CLIENT -q "GRANT ${role_b} TO ${user_name}"
$DATASTORE_CLIENT --user ${user_name} -q "SELECT * FROM cluster('test_shard_localhost', currentDatabase(), test)"
$DATASTORE_CLIENT -q "REVOKE ${role_b} FROM ${user_name}"

$DATASTORE_CLIENT -q "DROP TABLE test"
$DATASTORE_CLIENT -q "DROP USER ${user_name}"
$DATASTORE_CLIENT -q "DROP ROLE ${role_a}, ${role_b}"
$DATASTORE_CLIENT -q "DROP ROW POLICY ${row_policy_a}, ${row_policy_b} ON test"
