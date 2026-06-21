#!/usr/bin/env bash
# Tags: race

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS join_table_race"
$DATASTORE_CLIENT -q "CREATE TABLE join_table_race(id Int32, name String) ENGINE = Join(ANY, LEFT, id)"

for _ in {0..100}; do echo "INSERT INTO join_table_race VALUES ($RANDOM, '$RANDOM');"; done | $DATASTORE_CLIENT --ignore-error -nm > /dev/null 2> /dev/null &

for _ in {0..200}; do echo "SELECT count() FROM join_table_race FORMAT Null;"; done | $DATASTORE_CLIENT --ignore-error -nm > /dev/null 2> /dev/null &

for _ in {0..100}; do echo "TRUNCATE TABLE join_table_race;"; done | $DATASTORE_CLIENT --ignore-error -nm > /dev/null 2> /dev/null &

for _ in {0..100}; do echo "ALTER TABLE join_table_race DELETE WHERE id % 2 = 0;"; done | $DATASTORE_CLIENT --ignore-error -nm > /dev/null 2> /dev/null &

wait

$DATASTORE_CLIENT -q "TRUNCATE TABLE join_table_race"
$DATASTORE_CLIENT -q "INSERT INTO join_table_race VALUES (1, 'foo')"
$DATASTORE_CLIENT -q "SELECT id, name FROM join_table_race"

$DATASTORE_CLIENT -q "DROP TABLE join_table_race"
