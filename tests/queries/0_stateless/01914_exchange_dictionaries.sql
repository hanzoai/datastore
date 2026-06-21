-- Tags: no-ordinary-database, no-parallel
-- Tag no-ordinary-database: Requires Atomic database

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier} ENGINE=Atomic;
USE {DATASTORE_DATABASE_1:Identifier};

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.table_1;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.table_1 (id UInt64, value String) ENGINE=TinyLog;

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.table_2;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.table_2 (id UInt64, value String) ENGINE=TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table_1 VALUES (1, 'Table1');
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table_2 VALUES (2, 'Table2');

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE_1:Identifier}.dictionary_1;
CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dictionary_1 (id UInt64, value String)
PRIMARY KEY id
LAYOUT(DIRECT())
SOURCE(DATASTORE(DB currentDatabase() TABLE 'table_1'));

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE_1:Identifier}.dictionary_2;
CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dictionary_2 (id UInt64, value String)
PRIMARY KEY id
LAYOUT(DIRECT())
SOURCE(DATASTORE(DB currentDatabase() TABLE 'table_2'));

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dictionary_1;
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dictionary_2;

EXCHANGE DICTIONARIES {DATASTORE_DATABASE_1:Identifier}.dictionary_1 AND {DATASTORE_DATABASE_1:Identifier}.dictionary_2;

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dictionary_1;
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dictionary_2;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dictionary_1;
DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dictionary_2;

DROP TABLE {DATASTORE_DATABASE_1:Identifier}.table_1;
DROP TABLE {DATASTORE_DATABASE_1:Identifier}.table_2;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
