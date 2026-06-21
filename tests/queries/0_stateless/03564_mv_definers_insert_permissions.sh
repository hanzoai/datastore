#!/usr/bin/env bash
# Tags: no-replicated-database, no-async-insert

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

user1="user03564_1_${DATASTORE_DATABASE}_$RANDOM"
user2="user03564_2_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user1, $user2;
CREATE USER $user1, $user2;

CREATE TABLE $db.source
(
    a UInt64
)
ENGINE = MergeTree
ORDER BY a;

CREATE TABLE $db.destination
(
    a UInt64
)
ENGINE = MergeTree
ORDER BY a;

CREATE MATERIALIZED VIEW $db.mv TO $db.destination
DEFINER = $user1 SQL SECURITY DEFINER
AS SELECT *
FROM $db.source;

GRANT SELECT ON $db.source TO $user1;
GRANT INSERT ON $db.source TO $user1;
GRANT SELECT ON $db.destination TO $user1;
GRANT NONE ON $db.destination TO $user1;

GRANT SELECT ON $db.mv TO $user2;
GRANT INSERT ON $db.mv TO $user2;
GRANT SELECT ON $db.source TO $user2;
GRANT INSERT ON $db.source TO $user2;
GRANT SELECT ON $db.destination TO $user2;
GRANT INSERT ON $db.destination TO $user2;
EOF

(( $(${DATASTORE_CLIENT} --user $user2 --query "INSERT INTO $db.mv VALUES (10)" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --query "GRANT INSERT ON $db.destination TO $user1";
${DATASTORE_CLIENT} --user $user2 --query "INSERT INTO $db.mv VALUES (10)";

${DATASTORE_CLIENT} --query "DROP TABLE $db.mv";
${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user1, $user2";
