-- Tags: no-parallel, no-fasttest

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier} ENGINE = Memory;
USE {DATASTORE_DATABASE_1:Identifier};

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.simple_key_dictionary_source;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_dictionary_source
(
    id UInt64,
    value String
) ENGINE = TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_dictionary_source VALUES (1, 'First');
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_dictionary_source VALUES (2, 'Second');
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_dictionary_source VALUES (3, 'Third');

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE_1:Identifier}.simple_key_direct_dictionary;
CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.simple_key_direct_dictionary
(
    id UInt64,
    value String
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() DB currentDatabase() TABLE 'simple_key_dictionary_source'))
LAYOUT(DIRECT());

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.simple_key_direct_dictionary ORDER BY ALL;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.simple_key_direct_dictionary;
DROP TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_dictionary_source;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
