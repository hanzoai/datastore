#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest, long
# Tag no-parallel: Messes with internal cache
#     no-fasttest: Produces wrong results in fasttest, unclear why, didn't reproduce locally.
#     long: Sloooow ...

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# -- Attack 1:
#    - create a user,
#    - run a query whose result is stored in the query cache,
#    - drop the user, recreate it with the same name
#    - test that the cache entry is inaccessible

echo "Attack 1"

rnd=`tr -dc 1-9 </dev/urandom | head -c 5` # disambiguates the specific query in system.query_log below
# echo $rnd

# Start with empty query cache (QC).
${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS admin"
${DATASTORE_CLIENT} --query "CREATE USER admin"
${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS ON *.* TO admin WITH GRANT OPTION"

# Insert cache entry
${DATASTORE_CLIENT} --user "admin" --query "SELECT 0 == $rnd SETTINGS use_query_cache = 1"

# Check that the system view knows the new cache entry
${DATASTORE_CLIENT} --user "admin" --query "SELECT 'system.query_cache with old user', count(*) FROM system.query_cache"

# Run query again. The 1st run must be a cache miss, the 2nd run a cache hit
${DATASTORE_CLIENT} --user "admin" --query "SELECT 0 == $rnd SETTINGS use_query_cache = 1"
${DATASTORE_CLIENT} --user "admin" --query "SYSTEM FLUSH LOGS query_log"
${DATASTORE_CLIENT} --user "admin" --query "SELECT ProfileEvents['QueryCacheHits'], ProfileEvents['QueryCacheMisses'] FROM system.query_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND type = 'QueryFinish' AND current_database = currentDatabase() AND query = 'SELECT 0 == $rnd SETTINGS use_query_cache = 1' ORDER BY event_time_microseconds"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS admin"
${DATASTORE_CLIENT} --query "CREATE USER admin"
${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS ON *.* TO admin WITH GRANT OPTION"

# system.query_cache reports the old entry. That is okay since the system table only shows the query string, not the query result.
${DATASTORE_CLIENT} --user "admin" --query "SELECT 'system.query_cache with new user', count(*) FROM system.query_cache"

# Run same query as old user. Expect a cache miss.
${DATASTORE_CLIENT} --user "admin" --query "SELECT 0 == $rnd SETTINGS use_query_cache = 1"
${DATASTORE_CLIENT} --user "admin" --query "SYSTEM FLUSH LOGS query_log"
${DATASTORE_CLIENT} --user "admin" --query "SELECT ProfileEvents['QueryCacheHits'], ProfileEvents['QueryCacheMisses'] FROM system.query_log WHERE event_date >= yesterday() AND event_time >= now() - 600 AND type = 'QueryFinish' AND current_database = currentDatabase() AND query = 'SELECT 0 == $rnd SETTINGS use_query_cache = 1' ORDER BY event_time_microseconds"

# Cleanup
${DATASTORE_CLIENT} --query "DROP USER admin"
${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"

# -- Attack 2: (scenario from issue #58054)
#    - create a user,
#    - create two roles, each with different row policies
#    - cached query result in the context of the 1st role must must not be visible in the context of the 2nd role

echo "Attack 2"

# Start with empty query cache (QC).
${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS admin"
${DATASTORE_CLIENT} --query "CREATE USER admin"
${DATASTORE_CLIENT} --query "GRANT CURRENT GRANTS ON *.* TO admin WITH GRANT OPTION"

# Create table
${DATASTORE_CLIENT} --user "admin" --query "DROP TABLE IF EXISTS user_data"
${DATASTORE_CLIENT} --user "admin" --query "CREATE TABLE user_data (ID UInt32, userID UInt32) ENGINE = MergeTree ORDER BY userID"

# Create roles with row-level security

${DATASTORE_CLIENT} --user "admin" --query "DROP ROLE IF EXISTS user_role_1"
# ${DATASTORE_CLIENT} --user "admin" --query "DROP ROLE POLICY IF EXISTS user_policy_1"
${DATASTORE_CLIENT} --user "admin" --query "CREATE ROLE user_role_1"
${DATASTORE_CLIENT} --user "admin" --query "GRANT SELECT ON user_data TO user_role_1"
${DATASTORE_CLIENT} --user "admin" --query "CREATE ROW POLICY user_policy_1 ON user_data FOR SELECT USING userID = 1 TO user_role_1"

${DATASTORE_CLIENT} --user "admin" --query "DROP ROLE IF EXISTS user_role_2"
# ${DATASTORE_CLIENT} --user "admin" --query "DROP ROLE POLICY IF EXISTS user_policy_2"
${DATASTORE_CLIENT} --user "admin" --query "CREATE ROLE user_role_2"
${DATASTORE_CLIENT} --user "admin" --query "GRANT SELECT ON user_data TO user_role_2"
${DATASTORE_CLIENT} --user "admin" --query "CREATE ROW POLICY user_policy_2 ON user_data FOR SELECT USING userID = 2 TO user_role_2"

# Grant roles to admin
${DATASTORE_CLIENT} --user "admin" --query "GRANT user_role_1, user_role_2 TO admin"
${DATASTORE_CLIENT} --user "admin" --query "INSERT INTO user_data (ID, userID) VALUES (1, 1), (2, 2), (3, 1), (4, 3), (5, 2), (6, 1), (7, 4), (8, 2)"

# Test...
${DATASTORE_CLIENT} --user "admin" --query "SELECT '-- policy_1 test'"
${DATASTORE_CLIENT} --user "admin" "SET ROLE user_role_1; SELECT * FROM user_data" # should only return rows with userID = 1

${DATASTORE_CLIENT} --user "admin" --query "SELECT '-- policy_2 test'"
${DATASTORE_CLIENT} --user "admin" "SET ROLE user_role_2; SELECT * FROM user_data" # should only return rows with userID = 2

${DATASTORE_CLIENT} --user "admin" --query "SELECT '-- policy_1 with query cache test'"
${DATASTORE_CLIENT} --user "admin" "SET ROLE user_role_1; SELECT * FROM user_data SETTINGS use_query_cache = 1" # should only return rows with userID = 1

${DATASTORE_CLIENT} --user "admin" --query "SELECT '-- policy_2 with query cache test'"
${DATASTORE_CLIENT} --user "admin" "SET ROLE user_role_2; SELECT * FROM user_data SETTINGS use_query_cache = 1" # should only return rows with userID = 2 (not userID = 1!)

# Cleanup
${DATASTORE_CLIENT} --user "admin" --query "DROP ROLE user_role_1"
${DATASTORE_CLIENT} --user "admin" --query "DROP ROLE user_role_2"
${DATASTORE_CLIENT} --user "admin" --query "DROP TABLE user_data"
${DATASTORE_CLIENT} --query "DROP USER admin"
${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"
