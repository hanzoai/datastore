#!/usr/bin/env bash
# Tags: no-replicated-database, no-async-insert, no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user="user03701_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
-- Cleanup
DROP USER IF EXISTS $user;
CREATE USER $user IN memory;
GRANT ALL ON *.* TO $user;
REVOKE SET DEFINER ON * FROM $user;

CREATE TABLE $db.source (x Int64) ENGINE = MergeTree() ORDER BY x;
EOF

${DATASTORE_CLIENT} --user $user <<EOF
CREATE MATERIALIZED VIEW $db.test_view
(
    x Int64
)
ENGINE = MergeTree() ORDER BY x
DEFINER = CURRENT_USER SQL SECURITY DEFINER
AS SELECT x FROM $db.source;
EOF

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user;
EOF
