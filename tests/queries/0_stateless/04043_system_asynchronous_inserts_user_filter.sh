#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel
# no-parallel: concurrent SYSTEM FLUSH ASYNC INSERT QUEUE from other tests drains the pending queue

# Regression test: system.asynchronous_inserts must not leak cross-user insert metadata.
# A user without SHOW_USERS privilege must only see their own pending inserts.

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "
    DROP USER IF EXISTS secret_user_${DATASTORE_DATABASE};
    DROP USER IF EXISTS restricted_user_${DATASTORE_DATABASE};
    CREATE USER secret_user_${DATASTORE_DATABASE};
    CREATE USER restricted_user_${DATASTORE_DATABASE};
    DROP TABLE IF EXISTS ${DATASTORE_DATABASE}.async_insert_test;
    CREATE TABLE ${DATASTORE_DATABASE}.async_insert_test (x UInt64) ENGINE=MergeTree ORDER BY x;
    GRANT INSERT ON ${DATASTORE_DATABASE}.async_insert_test TO secret_user_${DATASTORE_DATABASE};
    GRANT SELECT ON system.asynchronous_inserts TO secret_user_${DATASTORE_DATABASE};
    GRANT SELECT ON system.asynchronous_inserts TO restricted_user_${DATASTORE_DATABASE};
"

# secret_user inserts with async_insert enabled and a very long flush timeout so the entry stays in the queue.
${DATASTORE_CLIENT} \
    --user "secret_user_${DATASTORE_DATABASE}" \
    --async_insert 1 \
    --async_insert_busy_timeout_max_ms 600000 \
    --async_insert_busy_timeout_min_ms 600000 \
    --wait_for_async_insert 0 \
    -q "INSERT INTO ${DATASTORE_DATABASE}.async_insert_test VALUES (42)"

# restricted_user must see 0 rows (no cross-user visibility).
echo "restricted_user sees:"
${DATASTORE_CLIENT} \
    --user "restricted_user_${DATASTORE_DATABASE}" \
    -q "SELECT count() FROM system.asynchronous_inserts WHERE table = 'async_insert_test' AND database = '${DATASTORE_DATABASE}'"

# secret_user must see their own row.
echo "secret_user sees:"
${DATASTORE_CLIENT} \
    --user "secret_user_${DATASTORE_DATABASE}" \
    -q "SELECT count() FROM system.asynchronous_inserts WHERE table = 'async_insert_test' AND database = '${DATASTORE_DATABASE}'"

# Admin (current session) must see all rows.
echo "admin sees:"
${DATASTORE_CLIENT} \
    -q "SELECT count() FROM system.asynchronous_inserts WHERE table = 'async_insert_test' AND database = '${DATASTORE_DATABASE}'"

${DATASTORE_CLIENT} -q "
    DROP USER IF EXISTS secret_user_${DATASTORE_DATABASE};
    DROP USER IF EXISTS restricted_user_${DATASTORE_DATABASE};
    DROP TABLE IF EXISTS ${DATASTORE_DATABASE}.async_insert_test;
"
