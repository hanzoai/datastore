-- https://github.com/ClickHouse/Datastore/issues/83757
SELECT 1 FROM loop('system', 'merge_tree_settings') LIMIT 1;
