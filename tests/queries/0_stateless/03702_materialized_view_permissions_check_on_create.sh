#!/usr/bin/env bash
# Tags: no-replicated-database

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

user="user03702_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user;
CREATE USER $user;
GRANT CREATE TABLE, SELECT, INSERT ON $db.numbers_copy TO $user;
GRANT SELECT ON $db.zeros TO $user;
GRANT CREATE VIEW ON *.* TO $user;

CREATE TABLE $db.numbers (x Int32) ORDER BY x;
CREATE TABLE $db.numbers_copy AS numbers;
CREATE TABLE $db.zeros (x Int32) ORDER BY x;
INSERT INTO $db.numbers SELECT * FROM numbers(10);
EOF

${DATASTORE_CLIENT} --user $user <<EOF
CREATE MATERIALIZED VIEW $db.mv TO $db.numbers_copy
AS SELECT n.x AS x
FROM $db.zeros
INNER JOIN
(
    SELECT *
    FROM $db.numbers
) AS n ON 1 = 1; -- { serverError ACCESS_DENIED }
EOF

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS $user;
EOF
