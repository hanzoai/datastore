-- https://github.com/ClickHouse/Datastore/pull/84605
SELECT position('a	a', '\t') > 0;
