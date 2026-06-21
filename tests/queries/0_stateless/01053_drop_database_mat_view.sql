SET send_logs_level = 'fatal';

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};
set allow_deprecated_database_ordinary=1;
-- Creation of a database with Ordinary engine emits a warning.
CREATE DATABASE {DATASTORE_DATABASE:Identifier} ENGINE=Ordinary; -- Different inner table name with Atomic

set allow_deprecated_syntax_for_merge_tree=1;
create table {DATASTORE_DATABASE:Identifier}.my_table ENGINE = MergeTree(day, (day), 8192) as select today() as day, 'mystring' as str;
show tables from {DATASTORE_DATABASE:Identifier};
create materialized view {DATASTORE_DATABASE:Identifier}.my_materialized_view ENGINE = MergeTree(day, (day), 8192) as select * from {DATASTORE_DATABASE:Identifier}.my_table;
show tables from {DATASTORE_DATABASE:Identifier};
select * from {DATASTORE_DATABASE:Identifier}.my_materialized_view;

DROP DATABASE {DATASTORE_DATABASE:Identifier};
