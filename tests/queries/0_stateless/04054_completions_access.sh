#!/usr/bin/env bash

# Test that system.completions respects per-table grants correctly.
# A user with only per-table SHOW TABLES/SHOW COLUMNS grants (no global grant)
# should see completions for their permitted tables, not others.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query "CREATE TABLE ${DATASTORE_DATABASE}.visible_table (id UInt32, name String) ENGINE = Memory;"
$DATASTORE_CLIENT --query "CREATE TABLE ${DATASTORE_DATABASE}.hidden_table (id UInt32, value Float64) ENGINE = Memory;"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_user;"
$DATASTORE_CLIENT --query "CREATE USER ${DATASTORE_DATABASE}_user IDENTIFIED WITH no_password;"
# Grant only per-table access (no global SHOW TABLES/SHOW COLUMNS grant)
$DATASTORE_CLIENT --query "GRANT SHOW TABLES ON ${DATASTORE_DATABASE}.visible_table TO ${DATASTORE_DATABASE}_user;"
$DATASTORE_CLIENT --query "GRANT SHOW COLUMNS ON ${DATASTORE_DATABASE}.visible_table TO ${DATASTORE_DATABASE}_user;"

echo "=== Per-table grant user sees the permitted table ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_user" \
    --query "SELECT word FROM system.completions WHERE context = 'table' AND belongs = '${DATASTORE_DATABASE}' ORDER BY word;"

echo "=== Per-table grant user sees columns of the permitted table ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_user" \
    --query "SELECT word FROM system.completions WHERE context = 'column' AND belongs = 'visible_table' ORDER BY word;"

echo "=== Per-table grant user does NOT see the hidden table ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_user" \
    --query "SELECT count() FROM system.completions WHERE context = 'table' AND word = 'hidden_table';"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_user;"

# Case A: per-db SHOW DATABASES grant controls context = 'database' rows
$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_db_user;"
$DATASTORE_CLIENT --query "CREATE USER ${DATASTORE_DATABASE}_db_user IDENTIFIED WITH no_password;"
$DATASTORE_CLIENT --query "GRANT SHOW DATABASES ON ${DATASTORE_DATABASE}.* TO ${DATASTORE_DATABASE}_db_user;"

echo "=== Per-db grant user sees the permitted database ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_db_user" \
    --query "SELECT word FROM system.completions WHERE context = 'database' AND word = '${DATASTORE_DATABASE}';"

echo "=== Per-db grant user does NOT see other databases ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_db_user" \
    --query "SELECT count() FROM system.completions WHERE context = 'database' AND word = 'default';"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_db_user;"

# Case B: per-db SHOW TABLES/SHOW COLUMNS grant controls table and column rows
$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_dbtables_user;"
$DATASTORE_CLIENT --query "CREATE USER ${DATASTORE_DATABASE}_dbtables_user IDENTIFIED WITH no_password;"
$DATASTORE_CLIENT --query "GRANT SHOW DATABASES ON ${DATASTORE_DATABASE}.* TO ${DATASTORE_DATABASE}_dbtables_user;"
$DATASTORE_CLIENT --query "GRANT SHOW TABLES ON ${DATASTORE_DATABASE}.* TO ${DATASTORE_DATABASE}_dbtables_user;"
$DATASTORE_CLIENT --query "GRANT SHOW COLUMNS ON ${DATASTORE_DATABASE}.* TO ${DATASTORE_DATABASE}_dbtables_user;"

echo "=== Per-db SHOW TABLES grant user sees all tables in the database ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_dbtables_user" \
    --query "SELECT word FROM system.completions WHERE context = 'table' AND belongs = '${DATASTORE_DATABASE}' ORDER BY word;"

echo "=== Per-db SHOW COLUMNS grant user sees columns of all tables ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_dbtables_user" \
    --query "SELECT word FROM system.completions WHERE context = 'column' AND belongs = 'visible_table' ORDER BY word;"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_dbtables_user;"

# Case C: SHOW TABLES granted but SHOW COLUMNS not granted — table visible, columns hidden
$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_notcols_user;"
$DATASTORE_CLIENT --query "CREATE USER ${DATASTORE_DATABASE}_notcols_user IDENTIFIED WITH no_password;"
$DATASTORE_CLIENT --query "GRANT SHOW DATABASES ON ${DATASTORE_DATABASE}.* TO ${DATASTORE_DATABASE}_notcols_user;"
$DATASTORE_CLIENT --query "GRANT SHOW TABLES ON ${DATASTORE_DATABASE}.visible_table TO ${DATASTORE_DATABASE}_notcols_user;"
# No SHOW COLUMNS grant at all

echo "=== SHOW TABLES only: table is visible ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_notcols_user" \
    --query "SELECT word FROM system.completions WHERE context = 'table' AND belongs = '${DATASTORE_DATABASE}' ORDER BY word;"

echo "=== SHOW TABLES only: columns are NOT visible ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_notcols_user" \
    --query "SELECT count() FROM system.completions WHERE context = 'column' AND belongs = 'visible_table';"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_notcols_user;"

# Case D: per-column SHOW COLUMNS revoke — revoked column is hidden, others visible
$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_percol_user;"
$DATASTORE_CLIENT --query "CREATE USER ${DATASTORE_DATABASE}_percol_user IDENTIFIED WITH no_password;"
$DATASTORE_CLIENT --query "GRANT SHOW DATABASES ON ${DATASTORE_DATABASE}.* TO ${DATASTORE_DATABASE}_percol_user;"
$DATASTORE_CLIENT --query "GRANT SHOW TABLES ON ${DATASTORE_DATABASE}.visible_table TO ${DATASTORE_DATABASE}_percol_user;"
$DATASTORE_CLIENT --query "GRANT SHOW COLUMNS ON ${DATASTORE_DATABASE}.visible_table TO ${DATASTORE_DATABASE}_percol_user;"
$DATASTORE_CLIENT --query "REVOKE SHOW COLUMNS(id) ON ${DATASTORE_DATABASE}.visible_table FROM ${DATASTORE_DATABASE}_percol_user;"
# 'id' column is revoked, 'name' should still be visible

echo "=== Per-column revoke: non-revoked column is visible ==="
$DATASTORE_CLIENT --user="${DATASTORE_DATABASE}_percol_user" \
    --query "SELECT word FROM system.completions WHERE context = 'column' AND belongs = 'visible_table' ORDER BY word;"

$DATASTORE_CLIENT --query "DROP USER IF EXISTS ${DATASTORE_DATABASE}_percol_user;"

# Case E: external tables (session temporary tables) branch
echo "=== Temporary table appears in completions ==="
$DATASTORE_CLIENT -nm --query "
CREATE TEMPORARY TABLE tmp_completions_04054 (x UInt32, y String);
SELECT word FROM system.completions WHERE context = 'table' AND word = 'tmp_completions_04054';
"
