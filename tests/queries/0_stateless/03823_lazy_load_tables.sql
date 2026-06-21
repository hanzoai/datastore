-- Tags: no-replicated-database

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};

CREATE DATABASE {DATASTORE_DATABASE_1:Identifier} ENGINE = Atomic SETTINGS lazy_load_tables = 1;

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.t1 (id UInt64, value String) ENGINE = MergeTree ORDER BY id;
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.t1 VALUES (1, 'hello'), (2, 'world');

-- Use the database so the view's AS clause resolves table names without explicit db prefix.
USE {DATASTORE_DATABASE_1:Identifier};
CREATE VIEW v1 AS SELECT * FROM t1;

DETACH DATABASE {DATASTORE_DATABASE_1:Identifier};
ATTACH DATABASE {DATASTORE_DATABASE_1:Identifier};

-- After re-attach, MergeTree shows as TableProxy; views load normally.
USE {DATASTORE_DATABASE_1:Identifier};
SELECT name, engine FROM system.tables WHERE database = currentDatabase() ORDER BY name;

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.t1 ORDER BY id;

SELECT name, engine FROM system.tables WHERE database = currentDatabase() ORDER BY name;

-- DROP on an unloaded lazy proxy forces nested load for cleanup.
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.t2 (x UInt32) ENGINE = MergeTree ORDER BY x;
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.t2 VALUES (42);

DETACH DATABASE {DATASTORE_DATABASE_1:Identifier};
ATTACH DATABASE {DATASTORE_DATABASE_1:Identifier};

USE {DATASTORE_DATABASE_1:Identifier};
SELECT name, engine FROM system.tables WHERE database = currentDatabase() AND name = 't2';

DROP TABLE {DATASTORE_DATABASE_1:Identifier}.t2;
SELECT count() FROM system.tables WHERE database = currentDatabase() AND name = 't2';

-- Verify views, materialized views, dictionaries, and table functions are NOT lazy-loaded.
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.src (id UInt64) ENGINE = MergeTree ORDER BY id;
CREATE MATERIALIZED VIEW {DATASTORE_DATABASE_1:Identifier}.mv ENGINE = MergeTree ORDER BY id AS SELECT id FROM {DATASTORE_DATABASE_1:Identifier}.src;
CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict (id UInt64) PRIMARY KEY id SOURCE(DATASTORE(TABLE 'src' DB currentDatabase())) LAYOUT(FLAT()) LIFETIME(0);

DETACH DATABASE {DATASTORE_DATABASE_1:Identifier};
ATTACH DATABASE {DATASTORE_DATABASE_1:Identifier};

USE {DATASTORE_DATABASE_1:Identifier};
SELECT name, engine FROM system.tables WHERE database = currentDatabase() AND name IN ('src', 'mv') ORDER BY name;
SELECT name FROM system.dictionaries WHERE database = currentDatabase() AND name = 'dict';

-- RENAME on an unloaded lazy proxy.
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.t3 (id UInt64) ENGINE = MergeTree ORDER BY id;

DETACH DATABASE {DATASTORE_DATABASE_1:Identifier};
ATTACH DATABASE {DATASTORE_DATABASE_1:Identifier};

USE {DATASTORE_DATABASE_1:Identifier};
RENAME TABLE {DATASTORE_DATABASE_1:Identifier}.t3 TO {DATASTORE_DATABASE_1:Identifier}.t3_renamed;
SELECT name, engine FROM system.tables WHERE database = currentDatabase() AND name = 't3_renamed';

-- ALTER on a lazy proxy triggers loading.
ALTER TABLE {DATASTORE_DATABASE_1:Identifier}.t3_renamed ADD COLUMN value String DEFAULT 'test';
SELECT name, type FROM system.columns WHERE database = currentDatabase() AND table = 't3_renamed' AND name = 'value';

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
