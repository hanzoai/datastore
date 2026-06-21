-- Tags: zookeeper
SET distributed_ddl_output_mode = 'none';

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};
CREATE DATABASE {DATASTORE_DATABASE:Identifier} ENGINE=Replicated('/datastore/databases/{database}', 'shard1', 'replica1');
USE {DATASTORE_DATABASE:Identifier};

CREATE TABLE 03655_keepermap (k UInt64) ENGINE = KeeperMap('/' || currentDatabase() || '/03655_keepermap') PRIMARY KEY (k);

SELECT '-- Before ALTER:';
SELECT 'local:', regexpExtract(create_table_query, '(`k`.+?)(\n|\))', 1) FROM system.tables WHERE database = currentDatabase() AND table = '03655_keepermap';
SELECT 'keeper:', regexpExtract(value, '(`k`.+?)(\n|\))', 1) FROM system.zookeeper WHERE path = '/datastore/databases/' || currentDatabase() || '/metadata';

ALTER TABLE 03655_keepermap COMMENT COLUMN k 'some comment';

SELECT '-- After ALTER:';
SELECT 'local:', regexpExtract(create_table_query, '(`k`.+?)(\n|\))', 1) FROM system.tables WHERE database = currentDatabase() AND table = '03655_keepermap';
SELECT 'keeper:', regexpExtract(value, '(`k`.+?)(\n|\))', 1) FROM system.zookeeper WHERE path = '/datastore/databases/' || currentDatabase() || '/metadata';

DROP DATABASE {DATASTORE_DATABASE:Identifier} SYNC;
