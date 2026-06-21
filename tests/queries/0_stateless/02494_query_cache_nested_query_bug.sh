#!/usr/bin/env bash
# Tags: no-parallel, no-fasttest
# Tag no-parallel: Messes with internal cache
#     no-fasttest: Produces wrong results in fasttest, unclear why, didn't reproduce locally.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Start with empty query cache (QC).
${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS tab"
${DATASTORE_CLIENT} --query "CREATE TABLE tab (a UInt64) ENGINE=MergeTree() ORDER BY a"
${DATASTORE_CLIENT} --query "INSERT INTO tab VALUES (1) (2) (3)"
${DATASTORE_CLIENT} --query "INSERT INTO tab VALUES (3) (4) (5)"

SETTINGS_NO_ANALYZER="SETTINGS use_query_cache=1, max_threads=1, enable_analyzer=0, merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability=0.0, optimize_trivial_count_query=1"
SETTINGS_ANALYZER="SETTINGS use_query_cache=1, max_threads=1, enable_analyzer=1, merge_tree_read_split_ranges_into_intersecting_and_non_intersecting_injection_probability=0.0, optimize_trivial_count_query=1"

# Verify that the first query does two aggregations and the second query zero aggregations. Since query cache is currently not integrated
# with EXPLAIN PLAN, we need to check the logs.
${DATASTORE_CLIENT} --allow_repeated_settings --send_logs_level=trace --query "SELECT count(a) / (SELECT sum(a) FROM tab) FROM tab $SETTINGS_NO_ANALYZER" 2>&1 | grep "Aggregated. " | wc -l
${DATASTORE_CLIENT} --allow_repeated_settings --send_logs_level=trace --query "SELECT count(a) / (SELECT sum(a) FROM tab) FROM tab $SETTINGS_NO_ANALYZER" 2>&1 | grep "Aggregated. " | wc -l

${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"

${DATASTORE_CLIENT} --allow_repeated_settings --send_logs_level=trace --query "SELECT count(a) / (SELECT sum(a) FROM tab) FROM tab $SETTINGS_ANALYZER" 2>&1 | grep "Aggregated. " | wc -l
${DATASTORE_CLIENT} --allow_repeated_settings --send_logs_level=trace --query "SELECT count(a) / (SELECT sum(a) FROM tab) FROM tab $SETTINGS_ANALYZER" 2>&1 | grep "Aggregated. " | wc -l

${DATASTORE_CLIENT} --query "SYSTEM CLEAR QUERY CACHE"
