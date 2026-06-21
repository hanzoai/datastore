#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "create table dst (number UInt64) engine = MergeTree ORDER BY number;"

error=$(${DATASTORE_CLIENT} --query "select number + sleep(0.1) as number from system.numbers limit 1000 settings max_block_size = 1 format Native" 2>/dev/null | ${DATASTORE_CLIENT} --max_execution_time 0.3 --timeout_overflow_mode throw --query "insert into dst format Native" 2>&1 ||:)

function check_error()
{
    error="$1"

    if echo "$error" | grep "TIMEOUT_EXCEEDED" > /dev/null
    then
        echo "timeout_overflow_mode throw OK"
        return 0
    fi

    if echo "$error" | grep "QUERY_WAS_CANCELLED" | grep "is killed in pending state" > /dev/null
    then
        echo "timeout_overflow_mode throw OK"
        return 0
    fi

    echo "Query ended in unexpected way:"
    echo "$error"
    return 1
}

check_error "$error"

# this is the test with PushingPipelineExecutor
${DATASTORE_CLIENT} --query "select number + sleep(0.1) as number from system.numbers limit 1000 settings max_block_size = 1 format Native" 2>/dev/null | ${DATASTORE_CLIENT} --max_threads=1 --max_execution_time 0.3 --timeout_overflow_mode break --query "insert into dst format Native" 2>&1 | grep -o "QUERY_WAS_CANCELLED"
# this is the test with PushingPipelineExecutorPushingAsyncPipelineExecutor
${DATASTORE_CLIENT} --query "select number + sleep(0.1) as number from system.numbers limit 1000 settings max_block_size = 1 format Native" 2>/dev/null | ${DATASTORE_CLIENT} --max_threads=3 --max_execution_time 0.3 --timeout_overflow_mode break --query "insert into dst format Native" 2>&1 | grep -o "QUERY_WAS_CANCELLED"
