#!/usr/bin/env bash
# Tags: no-fasttest
# Tag no-fasttest: Depends on AWS

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

other_user="user03667_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
DROP USER IF EXISTS other_user;
CREATE USER $other_user;
GRANT SELECT ON $db.* TO $other_user;
EOF

${DATASTORE_CLIENT} <<EOF
CREATE VIEW $db.test_view
SQL SECURITY DEFINER
AS SELECT * FROM s3Cluster('test_cluster_two_shards_localhost', 'http://localhost:11111/test/a.tsv');
EOF

${DATASTORE_CLIENT} --query "SELECT count() FROM $db.test_view"
${DATASTORE_CLIENT} --user $other_user --query "SELECT count() FROM $db.test_view"

${DATASTORE_CLIENT} --query "SELECT count() FROM $db.test_view SETTINGS enable_analyzer=0"
${DATASTORE_CLIENT} --user $other_user --query "SELECT count() FROM $db.test_view SETTINGS enable_analyzer=0"

${DATASTORE_CLIENT} <<EOF
DROP VIEW IF EXISTS $db.test_view;
DROP USER IF EXISTS $other_user;
EOF
