-- Tags: zookeeper, no-replicated-database, no-ordinary-database
-- no-replicated-database: the test explicitly creates a replicated database

SET allow_experimental_alias_table_engine = 1;

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier} FORMAT Null;
CREATE DATABASE {DATASTORE_DATABASE:Identifier} ENGINE = Replicated('/datastore/04239_storage_alias_missing_target_replicated_database_drop/{database}', 'shard1', 'replica1') FORMAT Null;
USE {DATASTORE_DATABASE:Identifier};

CREATE TABLE target_for_alias_missing_target (id UInt32) ENGINE = MergeTree ORDER BY id FORMAT Null;
CREATE TABLE alias_with_missing_target ENGINE = Alias('target_for_alias_missing_target') FORMAT Null;

DROP TABLE target_for_alias_missing_target FORMAT Null;

SELECT count() FROM system.tables WHERE database = currentDatabase() AND name = 'alias_with_missing_target';
DROP TABLE alias_with_missing_target FORMAT Null;
SELECT count() FROM system.tables WHERE database = currentDatabase() AND name = 'alias_with_missing_target';

DROP DATABASE {DATASTORE_DATABASE:Identifier} FORMAT Null;
