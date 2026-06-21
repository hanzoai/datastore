#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

DATA_DIR=$USER_FILES_PATH/$DATASTORE_TEST_UNIQUE_NAME
mkdir -p $DATA_DIR
cp -r $CURDIR/data_hive/ $DATA_DIR

$DATASTORE_CLIENT --query_id="test_03231_1_$DATASTORE_TEST_UNIQUE_NAME" --query "
    SELECT countDistinct(_path) FROM file('$DATA_DIR/data_hive/partitioning/column0=*/sample.parquet') WHERE column0 = 'Elizabeth' SETTINGS use_hive_partitioning=1, optimize_count_from_files=0;
"

$DATASTORE_CLIENT --query "
    SYSTEM FLUSH LOGS query_log;
"

for _ in {1..5}; do
    count=$( $DATASTORE_CLIENT --query "
        SELECT ProfileEvents['EngineFileLikeReadFiles'] FROM system.query_log 
        WHERE event_date >= yesterday() AND event_time >= now() - 600 AND query_id='test_03231_1_$DATASTORE_TEST_UNIQUE_NAME' AND 
        current_database = currentDatabase() and type='QueryFinish';" )
    if [[ "$count" == "1" ]]; then
        echo "1"
        break
    fi
    sleep 1
done

$DATASTORE_CLIENT --query_id="test_03231_2_$DATASTORE_TEST_UNIQUE_NAME" --query "
    SELECT countDistinct(_path) FROM file('$DATA_DIR/data_hive/partitioning/identifier=*/email.csv') WHERE identifier = 2070 SETTINGS use_hive_partitioning=1, optimize_count_from_files=0;
"

$DATASTORE_CLIENT --query "
    SYSTEM FLUSH LOGS query_log;
"

for _ in {1..5}; do
    count=$( $DATASTORE_CLIENT --query "
        SELECT ProfileEvents['EngineFileLikeReadFiles'] FROM system.query_log 
        WHERE event_date >= yesterday() AND event_time >= now() - 600 AND query_id='test_03231_2_$DATASTORE_TEST_UNIQUE_NAME' AND 
        current_database = currentDatabase() and type='QueryFinish';" )
    if [[ "$count" == "1" ]]; then
        echo "1"
        break
    fi
    sleep 1
done

$DATASTORE_CLIENT --query_id="test_03231_3_$DATASTORE_TEST_UNIQUE_NAME" --query "
    SELECT countDistinct(_path) FROM file('$DATA_DIR/data_hive/partitioning/array=*/sample.parquet') WHERE array = [1,2,3] SETTINGS use_hive_partitioning=1, optimize_count_from_files=0;
"

$DATASTORE_CLIENT --query "
    SYSTEM FLUSH LOGS query_log;
"

for _ in {1..5}; do
    count=$( $DATASTORE_CLIENT --query "
        SELECT ProfileEvents['EngineFileLikeReadFiles'] FROM system.query_log 
        WHERE event_date >= yesterday() AND event_time >= now() - 600 AND query_id='test_03231_3_$DATASTORE_TEST_UNIQUE_NAME' AND 
        current_database = currentDatabase() and type='QueryFinish';" )
    if [[ "$count" == "1" ]]; then
        echo "1"
        break
    fi
    sleep 1
done

rm -rf $DATA_DIR
