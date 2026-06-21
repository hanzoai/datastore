-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier} SYNC;

CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.dict_data (key UInt64, value UInt64) ENGINE=MergeTree ORDER BY tuple();
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.dict_data VALUES (2,20), (3,30), (4,40), (5,50);

CREATE DICTIONARY {DATASTORE_DATABASE_1:Identifier}.dict (key UInt64, value UInt64) PRIMARY KEY key SOURCE(DATASTORE(DB currentDatabase() TABLE 'dict_data' HOST '127.0.0.1' PORT tcpPort())) LIFETIME(0) LAYOUT(HASHED());

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.table (x UInt64, y UInt64 DEFAULT dictGet('dict', 'value', x)) ENGINE=MergeTree ORDER BY tuple();
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table (x) VALUES (2);
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table VALUES (toUInt64(3), toUInt64(15));

SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.table ORDER BY x;

SELECT 'status:';
SELECT status FROM system.dictionaries WHERE database={DATASTORE_DATABASE_1:String} AND name='dict';

DETACH DATABASE {DATASTORE_DATABASE_1:Identifier};
ATTACH DATABASE {DATASTORE_DATABASE_1:Identifier};

SELECT 'status_after_detach_and_attach:';
-- It can be not loaded, or not even finish attaching in case of asynchronous tables loading.
SELECT COALESCE((SELECT status FROM system.dictionaries WHERE database={DATASTORE_DATABASE_1:String} AND name='dict')::Nullable(String), 'NOT_LOADED');

INSERT INTO {DATASTORE_DATABASE_1:Identifier}.table (x) VALUES (toInt64(4));
SELECT * FROM {DATASTORE_DATABASE_1:Identifier}.table ORDER BY x;

SELECT 'status:';
SELECT status FROM system.dictionaries WHERE database={DATASTORE_DATABASE_1:String} AND name='dict';

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
