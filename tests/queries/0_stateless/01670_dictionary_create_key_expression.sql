-- Tags: no-parallel

CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.test_for_dictionary (value String) ENGINE=TinyLog;
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.test_for_dictionary VALUES ('Test1'), ('Test2'), ('Test3');

SELECT 'Simple';

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_query_log_dictionary_simple
(
    `value_id` UInt64 EXPRESSION cityHash64(value),
    `value` String
)
PRIMARY KEY value_id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'test_for_dictionary' DB currentDatabase()))
LIFETIME(MIN 1 MAX 10)
LAYOUT(HASHED());

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.test_query_log_dictionary_simple ORDER BY value_id;

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_query_log_dictionary_simple;

SELECT 'Complex';

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.test_query_log_dictionary_complex
(
    `value_id` UInt64 EXPRESSION cityHash64(value),
    `value_length` UInt64 EXPRESSION length(value),
    `value` String
)
PRIMARY KEY value_id, value_length
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'test_for_dictionary' DB currentDatabase()))
LIFETIME(MIN 1 MAX 10)
LAYOUT(COMPLEX_KEY_HASHED());

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.test_query_log_dictionary_complex ORDER BY value_id;

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_query_log_dictionary_complex;

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.test_for_dictionary;
DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
