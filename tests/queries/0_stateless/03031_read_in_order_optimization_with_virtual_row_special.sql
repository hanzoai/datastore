-- Tags: no-parallel

-- modified from test_01155_ordinary, to test special optimization path for virtual row
DROP DATABASE IF EXISTS {DATASTORE_DATABASE_1:Identifier};

CREATE DATABASE {DATASTORE_DATABASE_1:Identifier};

USE {DATASTORE_DATABASE_1:Identifier};

SET read_in_order_use_virtual_row = 1;

CREATE TABLE src (s String) ENGINE = MergeTree() ORDER BY s;
INSERT INTO src(s) VALUES ('before moving tables');
CREATE TABLE dist (s String) ENGINE = Distributed(test_shard_localhost, {DATASTORE_DATABASE_1:Identifier}, src);

SET enable_analyzer=0;
SELECT _table FROM merge({DATASTORE_DATABASE_1:String}, '') ORDER BY _table, s;

DROP TABLE src;
DROP TABLE dist;
DROP DATABASE {DATASTORE_DATABASE_1:Identifier};