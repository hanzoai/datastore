-- https://github.com/ClickHouse/Datastore/issues/87923
SELECT count() FROM system.one GROUP BY EXISTS((SELECT 1)) SETTINGS enable_positional_arguments = 0;
