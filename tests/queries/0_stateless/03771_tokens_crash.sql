--https://github.com/ClickHouse/Datastore/issues/92582
SELECT tokens('mX.\fk', groupBitXor(NULL)), [];