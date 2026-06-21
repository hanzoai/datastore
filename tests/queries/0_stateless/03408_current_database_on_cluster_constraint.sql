-- Tags: replica, no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};

CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};

SET distributed_ddl_entry_format_version = 2;
SET distributed_ddl_output_mode='throw';

CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.t0 ON CLUSTER 'test_cluster_two_shards_different_databases' (c0 Int, CONSTRAINT cc CHECK currentDatabase()) ENGINE = MergeTree() ORDER BY tuple();

DROP DATABASE {DATASTORE_DATABASE_1:Identifier};
