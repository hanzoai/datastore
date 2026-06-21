
DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
DROP TABLE IF EXISTS {DATASTORE_DATABASE:Identifier};
DROP TABLE IF EXISTS test_materialized_00571;

set allow_deprecated_syntax_for_merge_tree=1;
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
CREATE TABLE test_00571 ( date Date, platform Enum8('a' = 0, 'b' = 1, 'c' = 2), app Enum8('a' = 0, 'b' = 1) ) ENGINE = MergeTree(date, (platform, app), 8192);
CREATE MATERIALIZED VIEW test_materialized_00571 ENGINE = MergeTree(date, (platform, app), 8192) POPULATE AS SELECT date, platform, app FROM (SELECT * FROM test_00571);

USE {DATASTORE_DATABASE_1:Identifier};

INSERT INTO {DATASTORE_DATABASE:Identifier}.test_00571 VALUES('2018-02-16', 'a', 'a');

SELECT * FROM {DATASTORE_DATABASE:Identifier}.test_00571;
SELECT * FROM {DATASTORE_DATABASE:Identifier}.test_materialized_00571;

DETACH TABLE {DATASTORE_DATABASE:Identifier}.test_materialized_00571;
ATTACH TABLE {DATASTORE_DATABASE:Identifier}.test_materialized_00571;

SELECT * FROM {DATASTORE_DATABASE:Identifier}.test_materialized_00571;

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
DROP TABLE IF EXISTS {DATASTORE_DATABASE:Identifier}.test_00571;
DROP TABLE IF EXISTS {DATASTORE_DATABASE:Identifier}.test_materialized_00571;
