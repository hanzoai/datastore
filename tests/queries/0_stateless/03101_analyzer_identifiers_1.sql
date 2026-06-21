-- https://github.com/ClickHouse/Datastore/issues/23194
-- This test add query-templates for fuzzer
SET enable_analyzer = 1;

DROP DATABASE IF EXISTS {DATASTORE_DATABASE:Identifier};
CREATE DATABASE {DATASTORE_DATABASE:Identifier};
USE {DATASTORE_DATABASE:Identifier};

CREATE TABLE table (
    column UInt64,
    nest Nested
    (
        key Nested (
            subkey UInt16
        )
    )
) ENGINE = Memory();


SELECT t.column FROM table AS t;

USE default;
SELECT column FROM {DATASTORE_DATABASE:Identifier}.table;
USE {DATASTORE_DATABASE:Identifier};


SELECT {DATASTORE_DATABASE:Identifier}.table.column FROM table;

--

SELECT t1.x, t2.x, y FROM
    (SELECT x, y FROM VALUES ('x UInt16, y UInt16', (0,1))) AS t1,
    (SELECT x, z FROM VALUES ('x UInt16, z UInt16', (2,3))) AS t2;

SELECT '---';

SELECT 1;
SELECT dummy;
SELECT one.dummy;
SELECT system.one.dummy;

SELECT *;

--

SELECT nest.key.subkey FROM table;
SELECT table.nest FROM table ARRAY JOIN nest;

SELECT '---';

SELECT * FROM (SELECT [1, 2, 3] AS arr) ARRAY JOIN arr;

SELECT * FROM table ARRAY JOIN [1, 2, 3] AS arr;
