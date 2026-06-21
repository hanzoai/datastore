-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_simple_attributes_source_table
(
   id UInt64,
   value_first String,
   value_second String
)
ENGINE = TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_simple_attributes_source_table VALUES(0, 'value_0', 'value_second_0');
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_simple_attributes_source_table VALUES(1, 'value_1', 'value_second_1');
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_simple_attributes_source_table VALUES(2, 'value_2', 'value_second_2');

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_simple_attributes
(
   id UInt64,
   value_first String DEFAULT 'value_first_default',
   value_second String DEFAULT 'value_second_default'
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'simple_key_simple_attributes_source_table'))
LIFETIME(MIN 1 MAX 1000)
LAYOUT(HASHED())
SETTINGS(dictionary_use_async_executor=1, max_threads=8);

SELECT 'Dictionary hashed_dictionary_simple_key_simple_attributes';
SELECT 'dictGet existing value';
SELECT dictGet('hashed_dictionary_simple_key_simple_attributes', 'value_first', number) as value_first,
    dictGet('hashed_dictionary_simple_key_simple_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGet with non existing value';
SELECT dictGet('hashed_dictionary_simple_key_simple_attributes', 'value_first', number) as value_first,
    dictGet('hashed_dictionary_simple_key_simple_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictGetOrDefault existing value';
SELECT dictGetOrDefault('hashed_dictionary_simple_key_simple_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('hashed_dictionary_simple_key_simple_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGetOrDefault non existing value';
SELECT dictGetOrDefault('hashed_dictionary_simple_key_simple_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('hashed_dictionary_simple_key_simple_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictHas';
SELECT dictHas('hashed_dictionary_simple_key_simple_attributes', number) FROM system.numbers LIMIT 4;
SELECT 'select all values as input stream';
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_simple_attributes ORDER BY id;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_simple_attributes;

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_simple_attributes
(
   id UInt64,
   value_first String DEFAULT 'value_first_default',
   value_second String DEFAULT 'value_second_default'
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'simple_key_simple_attributes_source_table'))
LIFETIME(MIN 1 MAX 1000)
LAYOUT(SPARSE_HASHED());

SELECT 'Dictionary sparse_hashed_dictionary_simple_key_simple_attributes';
SELECT 'dictGet existing value';
SELECT dictGet('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_first', number) as value_first,
    dictGet('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGet with non existing value';
SELECT dictGet('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_first', number) as value_first,
    dictGet('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictGetOrDefault existing value';
SELECT dictGetOrDefault('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGetOrDefault non existing value';
SELECT dictGetOrDefault('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('sparse_hashed_dictionary_simple_key_simple_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictHas';
SELECT dictHas('sparse_hashed_dictionary_simple_key_simple_attributes', number) FROM system.numbers LIMIT 4;
SELECT 'select all values as input stream';
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_simple_attributes ORDER BY id;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_simple_attributes;

DROP TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_simple_attributes_source_table;

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_complex_attributes_source_table
(
   id UInt64,
   value_first String,
   value_second Nullable(String)
)
ENGINE = TinyLog;

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_complex_attributes_source_table VALUES(0, 'value_0', 'value_second_0');
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_complex_attributes_source_table VALUES(1, 'value_1', NULL);
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_complex_attributes_source_table VALUES(2, 'value_2', 'value_second_2');

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_complex_attributes
(
   id UInt64,
   value_first String DEFAULT 'value_first_default',
   value_second Nullable(String) DEFAULT 'value_second_default'
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'simple_key_complex_attributes_source_table'))
LIFETIME(MIN 1 MAX 1000)
LAYOUT(HASHED());

SELECT 'Dictionary hashed_dictionary_simple_key_complex_attributes';
SELECT 'dictGet existing value';
SELECT dictGet('hashed_dictionary_simple_key_complex_attributes', 'value_first', number) as value_first,
    dictGet('hashed_dictionary_simple_key_complex_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGet with non existing value';
SELECT dictGet('hashed_dictionary_simple_key_complex_attributes', 'value_first', number) as value_first,
    dictGet('hashed_dictionary_simple_key_complex_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictGetOrDefault existing value';
SELECT dictGetOrDefault('hashed_dictionary_simple_key_complex_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('hashed_dictionary_simple_key_complex_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGetOrDefault non existing value';
SELECT dictGetOrDefault('hashed_dictionary_simple_key_complex_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('hashed_dictionary_simple_key_complex_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictHas';
SELECT dictHas('hashed_dictionary_simple_key_complex_attributes', number) FROM system.numbers LIMIT 4;
SELECT 'select all values as input stream';
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_complex_attributes ORDER BY id;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_complex_attributes;

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_complex_attributes
(
   id UInt64,
   value_first String DEFAULT 'value_first_default',
   value_second Nullable(String) DEFAULT 'value_second_default'
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'simple_key_complex_attributes_source_table'))
LIFETIME(MIN 1 MAX 1000)
LAYOUT(HASHED());

SELECT 'Dictionary sparse_hashed_dictionary_simple_key_complex_attributes';
SELECT 'dictGet existing value';
SELECT dictGet('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_first', number) as value_first,
    dictGet('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGet with non existing value';
SELECT dictGet('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_first', number) as value_first,
    dictGet('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_second', number) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictGetOrDefault existing value';
SELECT dictGetOrDefault('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 3;
SELECT 'dictGetOrDefault non existing value';
SELECT dictGetOrDefault('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_first', number, toString('default')) as value_first,
    dictGetOrDefault('sparse_hashed_dictionary_simple_key_complex_attributes', 'value_second', number, toString('default')) as value_second FROM system.numbers LIMIT 4;
SELECT 'dictHas';
SELECT dictHas('sparse_hashed_dictionary_simple_key_complex_attributes', number) FROM system.numbers LIMIT 4;
SELECT 'select all values as input stream';
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_complex_attributes ORDER BY id;

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_complex_attributes;

DROP TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_complex_attributes_source_table;

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_hierarchy_table
(
    id UInt64,
    parent_id UInt64
) ENGINE = TinyLog();

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_hierarchy_table VALUES (1, 0);
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_hierarchy_table VALUES (2, 1);
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_hierarchy_table VALUES (3, 1);
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.simple_key_hierarchy_table VALUES (4, 2);

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_hierarchy
(
   id UInt64,
   parent_id UInt64 HIERARCHICAL
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'simple_key_hierarchy_table'))
LIFETIME(MIN 1 MAX 1000)
LAYOUT(HASHED());

SELECT 'Dictionary hashed_dictionary_simple_key_hierarchy';
SELECT 'dictGet';
SELECT dictGet('hashed_dictionary_simple_key_hierarchy', 'parent_id', number) FROM system.numbers LIMIT 5;
SELECT 'dictGetHierarchy';
SELECT dictGetHierarchy('hashed_dictionary_simple_key_hierarchy', toUInt64(1));
SELECT dictGetHierarchy('hashed_dictionary_simple_key_hierarchy', toUInt64(4));

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.hashed_dictionary_simple_key_hierarchy;

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_hierarchy
(
   id UInt64,
   parent_id UInt64 HIERARCHICAL
)
PRIMARY KEY id
SOURCE(DATASTORE(HOST 'localhost' PORT tcpPort() USER 'default' TABLE 'simple_key_hierarchy_table'))
LIFETIME(MIN 1 MAX 1000)
LAYOUT(HASHED());

SELECT 'Dictionary sparse_hashed_dictionary_simple_key_hierarchy';
SELECT 'dictGet';
SELECT dictGet('sparse_hashed_dictionary_simple_key_hierarchy', 'parent_id', number) FROM system.numbers LIMIT 5;
SELECT 'dictGetHierarchy';
SELECT dictGetHierarchy('sparse_hashed_dictionary_simple_key_hierarchy', toUInt64(1));
SELECT dictGetHierarchy('sparse_hashed_dictionary_simple_key_hierarchy', toUInt64(4));

DROP DICTIONARY {DATASTORE_DATABASE_1:Identifier}.sparse_hashed_dictionary_simple_key_hierarchy;

DROP TABLE {DATASTORE_DATABASE_1:Identifier}.simple_key_hierarchy_table;

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
