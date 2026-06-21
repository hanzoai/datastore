-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.dictionary_source_table
(
	key UInt8,
    value String
)
ENGINE = TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.dictionary_source_table VALUES (1, 'First');

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dictionary
(
    key UInt64,
    value String
)
PRIMARY KEY key
SOURCE(DATASTORE(DB currentDatabase() TABLE 'dictionary_source_table' HOST hostName() PORT tcpPort()))
LIFETIME(0)
LAYOUT(FLAT());

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dictionary;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dictionary;
DROP TABLE {DATASTORE_DATABASE_1:Identifier}.dictionary_source_table;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
