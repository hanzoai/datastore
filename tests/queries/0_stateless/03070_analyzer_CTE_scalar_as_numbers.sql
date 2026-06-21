-- https://github.com/ClickHouse/Datastore/issues/8259
SET enable_analyzer=1;
with
    (select 25) as something
select *, something
from numbers(toUInt64(assumeNotNull(something)));
