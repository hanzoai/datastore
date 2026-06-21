-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

DROP DICTIONARY IF EXISTS dict1;
CREATE DICTIONARY dict1
(
    id UInt64,
    value String
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() TABLE 'dict1'))
LAYOUT(DIRECT());

SELECT * FROM dict1; --{serverError BAD_ARGUMENTS}

DROP DICTIONARY dict1;

DROP DICTIONARY IF EXISTS dict2;
CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict2
(
    id UInt64,
    value String
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() DATABASE currentDatabase() TABLE 'dict2'))
LAYOUT(DIRECT());

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dict2; --{serverError BAD_ARGUMENTS}
DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict2;

DROP TABLE IF EXISTS {DATASTORE_DATABASE_1:Identifier}.dict3_source;
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.dict3_source
(
    id UInt64,
    value String
) ENGINE = TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.dict3_source VALUES (1, '1'), (2, '2'), (3, '3');

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict3
(
    id UInt64,
    value String
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() TABLE 'dict3_source' DATABASE currentDatabase()))
LAYOUT(DIRECT());

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.dict3;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict3;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
