-- Tags: no-parallel

DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE DATABASE IF NOT EXISTS {DATASTORE_DATABASE_1:Identifier};
CREATE TABLE {DATASTORE_DATABASE_1:Identifier}.t (n Int8) ENGINE=MergeTree ORDER BY n;
INSERT INTO {DATASTORE_DATABASE_1:Identifier}.t SELECT * FROM numbers(10);
USE {DATASTORE_DATABASE_1:Identifier};

-- We use the old setting here just to make sure we preserve it as an alias.
SET automatic_parallel_replicas_mode = 0;
SET allow_experimental_parallel_reading_from_replicas = 2, parallel_replicas_for_non_replicated_merge_tree = 1, cluster_for_parallel_replicas = 'parallel_replicas', max_parallel_replicas = 100;

SELECT * FROM loop({DATASTORE_DATABASE_1:Identifier}.t) LIMIT 15 FORMAT Null;
