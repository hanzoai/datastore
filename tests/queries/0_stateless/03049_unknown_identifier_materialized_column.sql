-- https://github.com/ClickHouse/Datastore/issues/54317
SET enable_analyzer=1;
DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};

CREATE DATABASE {DATASTORE_DATABASE:Identifier};
USE {DATASTORE_DATABASE:Identifier};

CREATE TABLE l (y String) Engine Memory;
CREATE TABLE r (d Date, y String, ty UInt16 MATERIALIZED toYear(d)) Engine Memory;
select * from l L left join r R on  L.y = R.y  where R.ty >= 2019;
select * from l left join r  on  l.y = r.y  where r.ty >= 2019;
select * from {DATASTORE_DATABASE:Identifier}.l left join {DATASTORE_DATABASE:Identifier}.r  on  l.y = r.y  where r.ty >= 2019;

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};
