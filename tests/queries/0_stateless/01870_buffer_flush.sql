-- Tags: no-parallel

-- Check that Buffer will be flushed before shutdown
-- (via DETACH DATABASE)

drop database if exists {DATASTORE_DATABASE_1:Identifier};
create database {DATASTORE_DATABASE_1:Identifier};

-- Right now the order for shutdown is defined and it is:
-- (prefixes are important, to define the order)
-- - a_data_01870
-- - z_buffer_01870
-- so on DETACH DATABASE the following error will be printed:
--
--     Destination table default.a_data_01870 doesn't exist. Block of data is discarded.
create table {DATASTORE_DATABASE_1:Identifier}.a_data_01870 as system.numbers Engine=TinyLog();
create table {DATASTORE_DATABASE_1:Identifier}.z_buffer_01870 as system.numbers Engine=Buffer({DATASTORE_DATABASE_1:Identifier}, a_data_01870, 1,
    100, 100, /* time */
    100, 100, /* rows */
    100, 1e6  /* bytes */
);
insert into {DATASTORE_DATABASE_1:Identifier}.z_buffer_01870 select * from system.numbers limit 5;
select count() from {DATASTORE_DATABASE_1:Identifier}.a_data_01870;
detach database {DATASTORE_DATABASE_1:Identifier};
attach database {DATASTORE_DATABASE_1:Identifier};
select count() from {DATASTORE_DATABASE_1:Identifier}.a_data_01870;

drop database {DATASTORE_DATABASE_1:Identifier};
