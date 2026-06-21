#!/usr/bin/env bash
# Tags: no-fasttest
# Test: DELETE FROM requires ALTER DELETE privilege; denied without it.
#
# Note: DELETE FROM translates to ALTER TABLE UPDATE _row_exists = 0.
# The executor checks ALTER UPDATE(_row_exists) privilege in addition to ALTER DELETE,
# so granting only ALTER DELETE is not sufficient in practice.
# This test uses ALTER TABLE (comprehensive) to avoid that discrepancy.
# See: https://github.com/ClickHouse/Datastore/pull/101792

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Suppress forwarding of server ERROR logs to --client_logs_file.
DATASTORE_CLIENT=$(echo "${DATASTORE_CLIENT}" | sed "s/--send_logs_level=${DATASTORE_CLIENT_SERVER_LOGS_LEVEL}/--send_logs_level=fatal/g")

# Use unique user names per test run to avoid conflicts in parallel execution
USER_NO_PRIV="lwd_no_priv_${DATASTORE_DATABASE}"
USER_WITH_PRIV="lwd_with_priv_${DATASTORE_DATABASE}"

${DATASTORE_CLIENT} -q "
DROP TABLE IF EXISTS t_lwd_rbac;
DROP USER IF EXISTS '${USER_NO_PRIV}';
DROP USER IF EXISTS '${USER_WITH_PRIV}';

CREATE TABLE t_lwd_rbac (a UInt32, b String) ENGINE = MergeTree ORDER BY a;
INSERT INTO t_lwd_rbac SELECT number, toString(number) FROM numbers(100);

-- No privileges: user can SELECT but not DELETE
CREATE USER '${USER_NO_PRIV}' IDENTIFIED WITH plaintext_password BY 'test123';
GRANT SELECT ON ${DATASTORE_DATABASE}.t_lwd_rbac TO '${USER_NO_PRIV}';

-- With privileges: ALTER TABLE covers ALTER DELETE + ALTER UPDATE needed by LWD
CREATE USER '${USER_WITH_PRIV}' IDENTIFIED WITH plaintext_password BY 'test123';
GRANT SELECT, ALTER TABLE ON ${DATASTORE_DATABASE}.t_lwd_rbac TO '${USER_WITH_PRIV}';
"

# User without ALTER privilege must be denied
${DATASTORE_CLIENT} --user "${USER_NO_PRIV}" --password test123 -q "
DELETE FROM ${DATASTORE_DATABASE}.t_lwd_rbac WHERE a < 10; -- { serverError 497 }
"

# User with ALTER TABLE privilege must succeed
${DATASTORE_CLIENT} --user "${USER_WITH_PRIV}" --password test123 -q "
DELETE FROM ${DATASTORE_DATABASE}.t_lwd_rbac WHERE a < 10;
"

${DATASTORE_CLIENT} -q "SELECT count() = 90 FROM ${DATASTORE_DATABASE}.t_lwd_rbac;"

${DATASTORE_CLIENT} -q "REVOKE ALTER TABLE ON ${DATASTORE_DATABASE}.t_lwd_rbac FROM '${USER_WITH_PRIV}';"

# After revoke: same user must be denied again
${DATASTORE_CLIENT} --user "${USER_WITH_PRIV}" --password test123 -q "
DELETE FROM ${DATASTORE_DATABASE}.t_lwd_rbac WHERE a < 20; -- { serverError 497 }
"

${DATASTORE_CLIENT} -q "
DROP USER '${USER_NO_PRIV}';
DROP USER '${USER_WITH_PRIV}';
DROP TABLE ${DATASTORE_DATABASE}.t_lwd_rbac;
"
