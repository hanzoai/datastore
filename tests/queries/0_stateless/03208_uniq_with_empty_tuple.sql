-- Tags: no-fasttest
-- https://github.com/ClickHouse/Datastore/issues/67303
SELECT uniqTheta(tuple());
SELECT uniq(tuple());
