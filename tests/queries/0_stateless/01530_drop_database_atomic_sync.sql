-- Tags: no-parallel
-- Tag no-parallel: creates database

drop database if exists {DATASTORE_DATABASE_1:Identifier} sync;

create database {DATASTORE_DATABASE_1:Identifier} Engine=Atomic;
USE {DATASTORE_DATABASE_1:Identifier};
create table {DATASTORE_DATABASE_1:Identifier}.data (key Int) Engine=ReplicatedMergeTree('/datastore/tables/{database}/db_01530_atomic/data', 'test') order by key;
drop database {DATASTORE_DATABASE_1:Identifier} sync;

create database {DATASTORE_DATABASE_1:Identifier} Engine=Atomic;
create table {DATASTORE_DATABASE_1:Identifier}.data (key Int) Engine=ReplicatedMergeTree('/datastore/tables/{database}/db_01530_atomic/data', 'test') order by key;
drop database {DATASTORE_DATABASE_1:Identifier} sync;


set database_atomic_wait_for_drop_and_detach_synchronously=1;

create database {DATASTORE_DATABASE_1:Identifier} Engine=Atomic;
create table {DATASTORE_DATABASE_1:Identifier}.data (key Int) Engine=ReplicatedMergeTree('/datastore/tables/{database}/db_01530_atomic/data', 'test') order by key;
drop database {DATASTORE_DATABASE_1:Identifier};

create database {DATASTORE_DATABASE_1:Identifier} Engine=Atomic;
create table {DATASTORE_DATABASE_1:Identifier}.data (key Int) Engine=ReplicatedMergeTree('/datastore/tables/{database}/db_01530_atomic/data', 'test') order by key;
drop database {DATASTORE_DATABASE_1:Identifier};


set database_atomic_wait_for_drop_and_detach_synchronously=0;

create database {DATASTORE_DATABASE_1:Identifier} Engine=Atomic;
create table {DATASTORE_DATABASE_1:Identifier}.data (key Int) Engine=ReplicatedMergeTree('/datastore/tables/{database}/db_01530_atomic/data', 'test') order by key;
drop database {DATASTORE_DATABASE_1:Identifier};

create database {DATASTORE_DATABASE_1:Identifier} Engine=Atomic;
create table {DATASTORE_DATABASE_1:Identifier}.data (key Int) Engine=ReplicatedMergeTree('/datastore/tables/{database}/db_01530_atomic/data', 'test') order by key; -- { serverError REPLICA_ALREADY_EXISTS }

set database_atomic_wait_for_drop_and_detach_synchronously=1;

drop database {DATASTORE_DATABASE_1:Identifier} sync;
