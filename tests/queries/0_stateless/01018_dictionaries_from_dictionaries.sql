-- Tags: no-parallel

SET send_logs_level = 'fatal';

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};

CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.table_for_dict
(
  key_column UInt64,
  second_column UInt8,
  third_column String,
  fourth_column Float64
)
ENGINE = MergeTree()
ORDER BY key_column;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table_for_dict SELECT number, number % 17, toString(number * number), number / 2.0 from numbers(100);

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict1
(
  key_column UInt64 DEFAULT 0,
  second_column UInt8 DEFAULT 1,
  third_column String DEFAULT 'qqq',
  fourth_column Float64 DEFAULT 42.0
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'table_for_dict' DB currentDatabase()))
LIFETIME(0)
LAYOUT(FLAT());

SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict1;

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict2
(
  key_column UInt64 DEFAULT 0,
  second_column UInt8 DEFAULT 1,
  third_column String DEFAULT 'qqq',
  fourth_column Float64 DEFAULT 42.0
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'dict1' DB currentDatabase()))
LIFETIME(0)
LAYOUT(HASHED());

SELECT count(*) FROM {DATASTORE_DATABASE_1:Identifier}.dict2;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table_for_dict SELECT number, number % 17, toString(number * number), number / 2.0 from numbers(100, 100);

-- Reload dictionaries in dependency order: table -> dict1 -> dict2
SYSTEM RELOAD DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict1;
SYSTEM RELOAD DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict2;

SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict2;
SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict1;

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict3
(
  key_column UInt64 DEFAULT 0,
  second_column UInt8 DEFAULT 1,
  third_column String DEFAULT 'qqq',
  fourth_column Float64 DEFAULT 42.0
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'dict2' DB currentDatabase()))
LIFETIME(0)
LAYOUT(HASHED());

SELECT count(*) FROM {DATASTORE_DATABASE_1:Identifier}.dict3;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table_for_dict SELECT number, number % 17, toString(number * number), number / 2.0 from numbers(200, 100);

-- Reload dictionaries in dependency order: table -> dict1 -> dict2 -> dict3
SYSTEM RELOAD DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict1;
SYSTEM RELOAD DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict2;
SYSTEM RELOAD DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict3;

SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict3;
SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict2;
SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict1;


CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict4
(
  key_column UInt64 DEFAULT 0,
  second_column UInt8 DEFAULT 1,
  third_column String DEFAULT 'qqq',
  fourth_column Float64 DEFAULT 42.0
)
PRIMARY KEY key_column
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'non_existing_table' DB currentDatabase()))
LIFETIME(0)
LAYOUT(HASHED());

SELECT count(*) FROM {DATASTORE_DATABASE_1:Identifier}.dict4; -- {serverError UNKNOWN_TABLE}

SELECT name from system.tables WHERE database = currentDatabase() ORDER BY name;
SELECT name from system.dictionaries WHERE database = currentDatabase() ORDER BY name;

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};

SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict3; --{serverError UNKNOWN_DATABASE}
SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict2; --{serverError UNKNOWN_DATABASE}
SELECT count(*) from {DATASTORE_DATABASE_1:Identifier}.dict1; --{serverError UNKNOWN_DATABASE}
