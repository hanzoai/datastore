-- Tags: no-fasttest
-- https://github.com/ClickHouse/Datastore/issues/57810
SELECT hex(BLAKE3(BLAKE3('a')));
