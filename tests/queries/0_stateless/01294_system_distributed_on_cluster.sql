-- Tags: distributed, no-parallel

-- just a smoke test

-- quirk for ON CLUSTER does not uses currentDatabase()
drop database if exists {DATASTORE_DATABASE_1:Identifier};
create database {DATASTORE_DATABASE_1:Identifier};
USE {DATASTORE_DATABASE_1:Identifier};
set distributed_ddl_output_mode='throw';

drop table if exists {DATASTORE_DATABASE_1:Identifier}.dist_01294;
create table {DATASTORE_DATABASE_1:Identifier}.dist_01294 as system.one engine=Distributed(test_shard_localhost, system, one);
-- flush
system flush distributed {DATASTORE_DATABASE_1:Identifier}.dist_01294;
system flush distributed on cluster test_shard_localhost {DATASTORE_DATABASE_1:Identifier}.dist_01294;
-- stop
system stop distributed sends {DATASTORE_DATABASE_1:Identifier}.dist_01294;
system stop distributed sends on cluster test_shard_localhost {DATASTORE_DATABASE_1:Identifier}.dist_01294;
-- start
system start distributed sends {DATASTORE_DATABASE_1:Identifier}.dist_01294;
system start distributed sends on cluster test_shard_localhost {DATASTORE_DATABASE_1:Identifier}.dist_01294;

drop database {DATASTORE_DATABASE_1:Identifier};
