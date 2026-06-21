#!/usr/bin/env bash
# Tags: long, no-replicated-database, no-async-insert

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


user1="user02884_1_${DATASTORE_DATABASE}_$RANDOM"
user2="user02884_2_${DATASTORE_DATABASE}_$RANDOM"
user3="user02884_3_${DATASTORE_DATABASE}_$RANDOM"
db=${DATASTORE_DATABASE}

${DATASTORE_CLIENT} <<EOF
CREATE TABLE $db.test_table (s String) ENGINE = MergeTree ORDER BY s;

DROP USER IF EXISTS $user1, $user2, $user3;
CREATE USER $user1, $user2, $user3;
GRANT SELECT ON $db.* TO $user1;
EOF

echo "===== StorageView ====="
${DATASTORE_CLIENT} <<EOF
CREATE VIEW $db.test_view_1 (s String)
AS SELECT * FROM $db.test_table;

CREATE DEFINER $user1 VIEW $db.test_view_2 (s String)
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_3 (s String)
DEFINER = $user1 SQL SECURITY DEFINER
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_4 (s String)
DEFINER = $user1 SQL SECURITY INVOKER
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_5 (s String)
SQL SECURITY INVOKER
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_6 (s String)
SQL SECURITY DEFINER
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_7 (s String)
DEFINER CURRENT_USER
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_8 (s String)
DEFINER $user3
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_9 (s String)
SQL SECURITY NONE
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_10 (s String)
SQL SECURITY DEFINER
AS SELECT * FROM $db.test_table;

CREATE VIEW $db.test_view_11 (s String)
SQL SECURITY DEFINER
AS SELECT * FROM $db.test_table
WHERE s = {param_id:String};
EOF

(( $(${DATASTORE_CLIENT} --query "SHOW TABLE $db.test_view_5" 2>&1 | grep -c "INVOKER") >= 1 )) && echo "OK" || echo "UNEXPECTED"
(( $(${DATASTORE_CLIENT} --query "SHOW TABLE $db.test_view_2" 2>&1 | grep -c "DEFINER = $user1") >= 1 )) && echo "OK" || echo "UNEXPECTED"

${DATASTORE_CLIENT} <<EOF
GRANT SELECT ON $db.test_view_1 TO $user2;
GRANT SELECT ON $db.test_view_2 TO $user2;
GRANT SELECT ON $db.test_view_3 TO $user2;
GRANT SELECT ON $db.test_view_4 TO $user2;
GRANT SELECT ON $db.test_view_5 TO $user2;
GRANT SELECT ON $db.test_view_6 TO $user2;
GRANT SELECT ON $db.test_view_7 TO $user2;
GRANT SELECT ON $db.test_view_8 TO $user2;
GRANT SELECT ON $db.test_view_9 TO $user2;
GRANT SELECT ON $db.test_view_10 TO $user2;
GRANT SELECT ON $db.test_view_11 TO $user2;
EOF

${DATASTORE_CLIENT} --query "INSERT INTO $db.test_table VALUES ('foo'), ('bar');"

(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_view_1" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_2"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_3"
(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_view_4" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_view_5" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_6"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_7"
(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_view_8" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_9"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_10"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_view_11(param_id='foo')"

${DATASTORE_CLIENT} --query "ALTER TABLE $db.test_view_10 MODIFY SQL SECURITY INVOKER"
(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_view_10" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
${DATASTORE_CLIENT} --query "SHOW CREATE TABLE $db.test_view_10" | grep -c "SQL SECURITY INVOKER"


echo "===== MaterializedView ====="
echo "create test_mv_1"
${DATASTORE_CLIENT} --query "
  CREATE MATERIALIZED VIEW $db.test_mv_1 (s String)
  ENGINE = MergeTree ORDER BY s
  DEFINER = $user1 SQL SECURITY DEFINER
  AS SELECT * FROM $db.test_table;
"

echo "create test_mv_2"
(( $(${DATASTORE_CLIENT} --query "
  CREATE MATERIALIZED VIEW $db.test_mv_2 (s String)
  ENGINE = MergeTree ORDER BY s
  SQL SECURITY INVOKER
  AS SELECT * FROM $db.test_table;
" 2>&1 | grep -c "SQL SECURITY INVOKER can't be specified for MATERIALIZED VIEW") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo "create test_mv_3"
${DATASTORE_CLIENT} --query "
  CREATE MATERIALIZED VIEW $db.test_mv_3 (s String)
  ENGINE = MergeTree ORDER BY s
  SQL SECURITY NONE
  AS SELECT * FROM $db.test_table;
"

echo "create test_mv_data"
${DATASTORE_CLIENT} --query "CREATE TABLE $db.test_mv_data (s String) ENGINE = MergeTree ORDER BY s;"

echo "create test_mv_4"
${DATASTORE_CLIENT} --query "
  CREATE MATERIALIZED VIEW $db.test_mv_4
  TO $db.test_mv_data
  DEFINER = $user1 SQL SECURITY DEFINER
  AS SELECT * FROM $db.test_table;
"

echo "create test_mv_5"
${DATASTORE_CLIENT} --query "
  CREATE MATERIALIZED VIEW $db.test_mv_5 (s String)
  ENGINE = MergeTree ORDER BY s
  DEFINER = $user2 SQL SECURITY DEFINER
  AS SELECT * FROM $db.test_table;
"

echo "grant select on test_mv_5 to user2"
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_mv_5 TO $user2"

echo "alter table test_mv_5"
${DATASTORE_CLIENT} --query "ALTER TABLE $db.test_mv_5 MODIFY SQL SECURITY NONE"
echo "select from test_mv_5 as user2"
${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_mv_5"
echo "show create table test_mv_5"
${DATASTORE_CLIENT} --query "SHOW CREATE TABLE $db.test_mv_5" | grep -c "SQL SECURITY NONE"

echo "grant select on test_mv_1 to user2"
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_mv_1 TO $user2"
echo "grant select on test_mv_3 to user2"
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_mv_3 TO $user2"
echo "grant select on test_mv_4 to user2"
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_mv_4 TO $user2"

echo "select from test_mv_1 as user2"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_mv_1"
echo "select from test_mv_3 as user2"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_mv_3"

echo "revoke select on test_mv_data from user1"
${DATASTORE_CLIENT} --query "REVOKE SELECT ON $db.test_mv_data FROM $user1"
echo "select from test_mv_4 as user2"
(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_mv_4" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
echo "insert into test_table"
(( $(${DATASTORE_CLIENT} --query "INSERT INTO $db.test_table VALUES ('foo'), ('bar');" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
echo "insert into test_table with materialized_views_ignore_errors=1"
(( $(${DATASTORE_CLIENT} --materialized_views_ignore_errors=1 --query "INSERT INTO $db.test_table VALUES ('foo'), ('bar');" 2>&1 | grep -c "Cannot push to the storage. Error is ignored because the setting materialized_views_ignore_errors is enabled.") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo "grant insert on test_mv_data to user1"
${DATASTORE_CLIENT} --query "GRANT INSERT ON $db.test_mv_data TO $user1"
echo "grant select on test_mv_data to user1"
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_mv_data TO $user1"
echo "insert into test_table"
${DATASTORE_CLIENT} --query "INSERT INTO $db.test_table VALUES ('foo'), ('bar');"
echo "select from test_mv_4 as user2"
${DATASTORE_CLIENT} --user $user2 --query "SELECT count() FROM $db.test_mv_4"

echo "revoke select on test_table from user1"
${DATASTORE_CLIENT} --query "REVOKE SELECT ON $db.test_table FROM $user1"
echo "select from test_mv_4"
(( $(${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_mv_4" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
echo "insert into test_table"
(( $(${DATASTORE_CLIENT} --query "INSERT INTO $db.test_table VALUES ('foo'), ('bar');" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo "create tables"
${DATASTORE_CLIENT} <<EOF
CREATE TABLE $db.source
(
    a UInt64
)
ENGINE = MergeTree
ORDER BY a;

CREATE TABLE $db.destination1
(
    a UInt64
)
ENGINE = MergeTree
ORDER BY a;

CREATE TABLE $db.destination2
(
    a UInt64
)
ENGINE = MergeTree
ORDER BY a;

CREATE MATERIALIZED VIEW $db.mv1 TO $db.destination1
AS SELECT *
FROM $db.source;

ALTER TABLE $db.mv1 MODIFY DEFINER=default SQL SECURITY DEFINER;

CREATE MATERIALIZED VIEW $db.mv2 TO $db.destination2
AS SELECT *
FROM $db.destination1;
EOF

echo "insert into source"
(( $(${DATASTORE_CLIENT} --user $user2 --query "INSERT INTO $db.source SELECT * FROM generateRandom() LIMIT 100 SETTINGS optimize_trivial_insert_select = 0" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"
echo "grant insert on source to user2"
${DATASTORE_CLIENT} --query "GRANT INSERT ON $db.source TO $user2"
echo "insert into source as user2"
${DATASTORE_CLIENT} --user $user2 --query "INSERT INTO $db.source SELECT * FROM generateRandom() LIMIT 100 SETTINGS optimize_trivial_insert_select = 0"

echo "select from destination1"
${DATASTORE_CLIENT} --query "SELECT count() FROM destination1"
echo "select from destination2"
${DATASTORE_CLIENT} --query "SELECT count() FROM destination2"

echo "alter table test_table"
(( $(${DATASTORE_CLIENT} --query "ALTER TABLE test_table MODIFY SQL SECURITY INVOKER" 2>&1 | grep -c "is not supported") >= 1 )) && echo "OK" || echo "UNEXPECTED"

echo "create view"
(( $(${DATASTORE_CLIENT} --user $user1 --query "
  CREATE VIEW $db.test_view_broken
  SQL SECURITY DEFINER
  DEFINER CURRENT_USER
  DEFINER $user2
  AS SELECT * FROM $db.test_table;
" 2>&1 | grep -c "Syntax error") >= 1 )) && echo "Syntax error" || echo "UNEXPECTED"

echo "===== TestGrants ====="
${DATASTORE_CLIENT} --query "GRANT CREATE ON *.* TO $user1"
${DATASTORE_CLIENT} --query "GRANT SELECT ON $db.test_table TO $user1, $user2"

${DATASTORE_CLIENT} --user $user1 --query "
  CREATE VIEW $db.test_view_g_1
  DEFINER = CURRENT_USER SQL SECURITY DEFINER
  AS SELECT * FROM $db.test_table;
"

(( $(${DATASTORE_CLIENT} --user $user1 --query "
  CREATE VIEW $db.test_view_g_2
  DEFINER = $user2
  AS SELECT * FROM $db.test_table;
" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

${DATASTORE_CLIENT} --query "GRANT SET DEFINER ON $user2 TO $user1"

${DATASTORE_CLIENT} --user $user1 --query "
  CREATE VIEW $db.test_view_g_2
  DEFINER = $user2
  AS SELECT * FROM $db.test_table;
"

(( $(${DATASTORE_CLIENT} --user $user1 --query "
  CREATE VIEW $db.test_view_g_3
  SQL SECURITY NONE
  AS SELECT * FROM $db.test_table;
" 2>&1 | grep -c "Not enough privileges") >= 1 )) && echo "OK" || echo "UNEXPECTED"

${DATASTORE_CLIENT} --query "GRANT SET DEFINER ON $user2 TO $user1"

echo "===== TestRowPolicy ====="
${DATASTORE_CLIENT} <<EOF
CREATE TABLE $db.test_row_t (x Int32, y Int32) ENGINE = MergeTree ORDER BY x;

CREATE VIEW $db.test_view_row_1 DEFINER = $user1 SQL SECURITY DEFINER AS SELECT x, y AS z FROM $db.test_row_t;
CREATE ROW POLICY r1 ON $db.test_row_t FOR SELECT USING x <= y TO $user1;
CREATE ROW POLICY r2 ON $db.test_view_row_1 FOR SELECT USING x >= z TO $user2;

INSERT INTO $db.test_row_t VALUES (1, 2), (1, 1), (2, 2), (3, 2), (4, 0);

GRANT SELECT ON $db.test_view_row_1 to $user2;
EOF

${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_view_row_1"

${DATASTORE_CLIENT} <<EOF
CREATE TABLE $db.test_row_t2 (x Int32, y Int32) ENGINE = MergeTree ORDER BY x;

CREATE VIEW $db.test_mv_row_2 DEFINER = $user1 SQL SECURITY DEFINER AS SELECT x, y AS z FROM $db.test_row_t2;
CREATE ROW POLICY r1 ON $db.test_row_t2 FOR SELECT USING x <= y TO $user1;
CREATE ROW POLICY r2 ON $db.test_mv_row_2 FOR SELECT USING x >= z TO $user2;

INSERT INTO $db.test_row_t2 VALUES (5, 6), (6, 5), (6, 6), (8, 7), (9, 9);

GRANT SELECT ON $db.test_mv_row_2 to $user2;
EOF

${DATASTORE_CLIENT} --user $user2 --query "SELECT * FROM $db.test_mv_row_2"

echo "===== TestInsertChain ====="

${DATASTORE_CLIENT} <<EOF
CREATE TABLE $db.session_events(
    clientId UUID,
    sessionId UUID,
    pageId UUID,
    timestamp DateTime,
    type String
)
ENGINE = MergeTree
ORDER BY (timestamp);

CREATE TABLE $db.materialized_events(
    clientId UUID,
    sessionId UUID,
    pageId UUID,
    timestamp DateTime,
    type String
)
ENGINE = MergeTree
ORDER BY (timestamp);

CREATE MATERIALIZED VIEW $db.events_mv TO $db.materialized_events AS
SELECT
    clientId,
    sessionId,
    pageId,
    timestamp,
    type
FROM
    $db.session_events;

GRANT INSERT ON $db.session_events TO $user3;
GRANT SELECT ON $db.session_events TO $user3;
EOF

${DATASTORE_CLIENT} --user $user3 --query "INSERT INTO $db.session_events SELECT * FROM generateRandom('clientId UUID, sessionId UUID, pageId UUID, timestamp DateTime, type Enum(\'type1\', \'type2\')', 1, 10, 2) LIMIT 1000 SETTINGS optimize_trivial_insert_select = 0"
${DATASTORE_CLIENT} --user $user3 --query "SELECT count(*) FROM session_events"
${DATASTORE_CLIENT} --query "SELECT count(*) FROM materialized_events"

echo "===== TestOnCluster ====="
${DATASTORE_CLIENT} <<EOF

CREATE TABLE $db.test_cluster ON CLUSTER test_shard_localhost (a String) Engine = MergeTree() ORDER BY a FORMAT Null;
CREATE TABLE $db.test_cluster_2 ON CLUSTER test_shard_localhost (a String) Engine = MergeTree() ORDER BY a FORMAT Null;
CREATE MATERIALIZED VIEW $db.cluster_mv ON CLUSTER test_shard_localhost TO $db.test_cluster_2 AS SELECT * FROM $db.test_cluster FORMAT Null;
ALTER TABLE $db.cluster_mv ON CLUSTER test_shard_localhost MODIFY DEFINER = $user3 FORMAT Null;
EOF

${DATASTORE_CLIENT} --query "SHOW CREATE TABLE $db.cluster_mv" | grep -c "DEFINER = $user3"

${DATASTORE_CLIENT} <<EOF
DROP TABLE $db.test_mv_1;
DROP TABLE $db.test_mv_3;
DROP TABLE $db.test_mv_4;
DROP TABLE $db.test_mv_5;

DROP TABLE $db.mv1;
DROP TABLE $db.mv2;

DROP TABLE $db.test_view_row_1;
DROP TABLE $db.test_view_g_1;
DROP TABLE $db.test_view_g_2;
DROP TABLE $db.test_mv_row_2;

DROP TABLE $db.test_view_2;
DROP TABLE $db.test_view_3;
DROP TABLE $db.test_view_4;
DROP TABLE $db.test_view_5;
DROP TABLE $db.test_view_6;
DROP TABLE $db.test_view_7;
DROP TABLE $db.test_view_8;
DROP TABLE $db.test_view_9;
DROP TABLE $db.test_view_10;
DROP TABLE $db.test_view_11;

DROP TABLE $db.cluster_mv ON CLUSTER test_shard_localhost;

DROP TABLE $db.materialized_events;
EOF
${DATASTORE_CLIENT} --query "DROP USER IF EXISTS $user1, $user2, $user3";
