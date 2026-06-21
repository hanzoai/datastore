#!/usr/bin/env bash
# Tags: no-replicated-database, no-async-insert, no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

ephemeral="ephemeral03580_${DATASTORE_DATABASE}_$RANDOM"
ephemeral_definer="${ephemeral}:definer"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $ephemeral;
CREATE USER $ephemeral IN memory;

CREATE TABLE $db.source (x Int64) ENGINE = MergeTree() ORDER BY x;

CREATE MATERIALIZED VIEW $db.test_mv
(
    x Int64
)
ENGINE = MergeTree() ORDER BY x
DEFINER = $ephemeral SQL SECURITY DEFINER
AS SELECT x FROM $db.source;
EOF

${DATASTORE_CLIENT} --query "SHOW CREATE TABLE $db.test_mv" | grep -c $ephemeral_definer
(( $(${DATASTORE_CLIENT} --query "DROP USER '$ephemeral_definer'" 2>&1 | grep -c "HAVE_DEPENDENT_OBJECTS") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --query "DROP USER $ephemeral"
${DATASTORE_CLIENT} --query "SHOW USERS" | grep -c $ephemeral_definer
${DATASTORE_CLIENT} --query "DROP TABLE $db.test_mv"
${DATASTORE_CLIENT} --query "SHOW USERS" | grep -c $ephemeral_definer
echo "Done"
