#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Create test files in the per-test unique directory
mkdir -p "${DATASTORE_USER_FILES_UNIQUE}/subdir"
echo -n 'hello' > "${DATASTORE_USER_FILES_UNIQUE}/a.txt"
echo -n 'world' > "${DATASTORE_USER_FILES_UNIQUE}/b.txt"
echo -n 'nested' > "${DATASTORE_USER_FILES_UNIQUE}/subdir/c.txt"

# Relative path inside user_files
TEST_REL="${DATASTORE_TEST_UNIQUE_NAME}"

# List files and check basic columns (name, type, is_symlink, depth)
$DATASTORE_CLIENT --query "
    SELECT name, type, is_symlink, depth
    FROM filesystem('${TEST_REL}')
    WHERE name IN ('a.txt', 'b.txt', 'c.txt', 'subdir')
    ORDER BY name
"

# Check size column for regular files
$DATASTORE_CLIENT --query "
    SELECT name, size
    FROM filesystem('${TEST_REL}')
    WHERE name IN ('a.txt', 'b.txt', 'c.txt')
    ORDER BY name
"

# Check content column
$DATASTORE_CLIENT --query "
    SELECT name, content
    FROM filesystem('${TEST_REL}')
    WHERE name IN ('a.txt', 'b.txt', 'c.txt')
    ORDER BY name
"

# LIMIT works
$DATASTORE_CLIENT --query "
    SELECT name
    FROM filesystem('${TEST_REL}')
    WHERE type = 'regular'
    ORDER BY name
    LIMIT 1
"

# Check that content is NULL for directories
$DATASTORE_CLIENT --query "
    SELECT name, content IS NULL
    FROM filesystem('${TEST_REL}')
    WHERE name = 'subdir'
"

# Clean up
rm -rf "${DATASTORE_USER_FILES_UNIQUE:?}"
