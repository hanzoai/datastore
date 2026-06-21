-- https://github.com/ClickHouse/Datastore/issues/85973#issuecomment-3228974538
SELECT count() != 0 FROM (Select definer FROM `system`.`tables`);