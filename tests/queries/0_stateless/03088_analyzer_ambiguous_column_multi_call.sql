-- https://github.com/ClickHouse/Datastore/issues/61014
SET enable_analyzer=1;

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};
create database {DATASTORE_DATABASE:Identifier};

create table {DATASTORE_DATABASE:Identifier}.a (i int) engine = Log();

select
  {DATASTORE_DATABASE:Identifier}.a.i
from
  {DATASTORE_DATABASE:Identifier}.a,
  {DATASTORE_DATABASE:Identifier}.a as x;
