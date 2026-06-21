-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier} ENGINE=Atomic;
USE {DATASTORE_DATABASE_1:Identifier};

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_source_table_1;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.test_source_table_1
(
    id UInt64,
    value String
) ENGINE=TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.test_source_table_1 VALUES (0, 'Value0');

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_dictionary;
CREATE OR REPLACE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_dictionary
(
    id UInt64,
    value String
)
PRIMARY KEY id
LAYOUT(DIRECT())
SOURCE(DATASTORE(DB currentDatabase() TABLE 'test_source_table_1'));

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.test_dictionary;

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_source_table_2;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.test_source_table_2
(
    id UInt64,
    value_1 String
) ENGINE=TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.test_source_table_2 VALUES (0, 'Value1');

CREATE OR REPLACE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_dictionary
(
    id UInt64,
    value_1 String
)
PRIMARY KEY id
LAYOUT(HASHED())
SOURCE(DATASTORE(DB currentDatabase() TABLE 'test_source_table_2'))
LIFETIME(0);

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.test_dictionary;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_dictionary;

DROP TABLE {DATASTORE_DATABASE_1:Identifier}.test_source_table_1;
DROP TABLE {DATASTORE_DATABASE_1:Identifier}.test_source_table_2;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
