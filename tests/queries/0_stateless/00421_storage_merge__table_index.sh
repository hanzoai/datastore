#!/usr/bin/env bash

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

for i in $(seq -w 0 2 20); do
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS merge_item_$i"
    $DATASTORE_CLIENT -q "CREATE TABLE merge_item_$i (d Int8) ENGINE = Memory"
    $DATASTORE_CLIENT -q "INSERT INTO merge_item_$i VALUES ($i)"
done

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS merge_storage"
$DATASTORE_CLIENT -q "CREATE TABLE merge_storage (d Int8) ENGINE = Merge('${DATASTORE_DATABASE}', '^merge_item_')"
$DATASTORE_CLIENT --max_threads=1 -q "SELECT _table, d FROM merge_storage WHERE _table LIKE 'merge_item_1%' ORDER BY _table"
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS merge_storage"

for i in $(seq -w 0 2 20); do $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS merge_item_$i"; done
