#!/usr/bin/env bash
# Tags: no-random-settings
# no-random-settings: we test interaction between explicit settings and compatibility

# Reproduces a coordinator/replica column-name mismatch caused by the fix in PR#97078/#99311.

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS t_repro_04034"
${DATASTORE_CLIENT} -q "CREATE TABLE t_repro_04034 (id UInt64) ENGINE = MergeTree ORDER BY id"
${DATASTORE_CLIENT} -q "INSERT INTO t_repro_04034 SELECT number % 5 FROM numbers(100)"

# Settings sent via client flags go through TCPHandler's passed_settings path, matching how the stress test randomiser injects settings
${DATASTORE_CLIENT} \
    --enable_analyzer=1 \
    --compatibility='23.8' \
    --enable_parallel_replicas=1 \
    --max_parallel_replicas=3 \
    --cluster_for_parallel_replicas='parallel_replicas' \
    --parallel_replicas_for_non_replicated_merge_tree=1 \
    -q "SELECT sum(id = 3 OR id = 1 OR id = 2) AS x FROM t_repro_04034"

${DATASTORE_CLIENT} -q "DROP TABLE t_repro_04034"
