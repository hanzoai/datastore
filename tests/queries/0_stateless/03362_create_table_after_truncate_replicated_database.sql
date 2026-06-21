-- Tags: zookeeper, no-replicated-database, no-ordinary-database
-- no-replicated-database: we explicitly run this test by creating a replicated database

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};

CREATE DATABASE {DATASTORE_DATABASE:Identifier} ENGINE=Replicated('/datastore/databases/{database}', 'shard1', 'replica1') FORMAT NULL;

USE {DATASTORE_DATABASE:Identifier};

CREATE TABLE t1 (x UInt8, y String) ENGINE=ReplicatedMergeTree ORDER BY x FORMAT NULL;

TRUNCATE DATABASE {DATASTORE_DATABASE:Identifier}; -- { serverError 48 }

DROP DATABASE {DATASTORE_DATABASE:Identifier};
