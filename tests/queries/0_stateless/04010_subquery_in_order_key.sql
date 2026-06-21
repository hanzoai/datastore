-- https://github.com/ClickHouse/Datastore/issues/74421
CREATE TABLE t0 (c0 Int) ENGINE=MergeTree() ORDER BY(c0 + (SELECT 1)) SETTINGS allow_nullable_key = 1; -- { serverError BAD_ARGUMENTS }
