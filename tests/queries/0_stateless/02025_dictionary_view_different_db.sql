-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_table;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.test_table
(
    id UInt64,
    value String
) ENGINE=TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.test_table VALUES (0, 'Value');

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_dictionary
(
    id UInt64,
    value String
)
PRIMARY KEY id
LAYOUT(DIRECT())
SOURCE(DATASTORE(TABLE 'test_table' DB currentDatabase()));

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.view_table;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.view_table
(
    id UInt64,
    value String
) ENGINE=TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.view_table VALUES (0, 'ViewValue');

DROP VIEW IF EXISTS test_view_different_db;
CREATE VIEW test_view_different_db AS SELECT id, value, dictGet('test_dictionary', 'value', id) FROM view_table;
SELECT * FROM test_view_different_db;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_dictionary;
DROP TABLE {DATASTORE_DATABASE_1:Identifier}.test_table;
DROP TABLE {DATASTORE_DATABASE_1:Identifier}.view_table;

DROP VIEW test_view_different_db;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
