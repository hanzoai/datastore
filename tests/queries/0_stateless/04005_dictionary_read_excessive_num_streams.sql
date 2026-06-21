-- Regression test: reading from a dictionary with very large max_streams
-- should not cause excessive memory allocation.

DROP DICTIONARY IF EXISTS {DATASTORE_DATABASE:Identifier}.test_dict_04005;
DROP TABLE IF EXISTS {DATASTORE_DATABASE:Identifier}.test_source_04005;

CREATE TABLE {DATASTORE_DATABASE:Identifier}.test_source_04005 (id UInt64, value String) ENGINE = Memory;
INSERT INTO {DATASTORE_DATABASE:Identifier}.test_source_04005 VALUES (1, 'a'), (2, 'b'), (3, 'c');

CREATE DICTIONARY {DATASTORE_DATABASE:Identifier}.test_dict_04005 (id UInt64, value String)
PRIMARY KEY id
SOURCE(DATASTORE(TABLE 'test_source_04005' DB currentDatabase()))
LAYOUT(FLAT())
LIFETIME(0);

SELECT * FROM {DATASTORE_DATABASE:Identifier}.test_dict_04005
ORDER BY id
SETTINGS max_threads = 1025, max_streams_to_max_threads_ratio = 1048576;

DROP DICTIONARY {DATASTORE_DATABASE:Identifier}.test_dict_04005;
DROP TABLE {DATASTORE_DATABASE:Identifier}.test_source_04005;
