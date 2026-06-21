#!/usr/bin/env bash
# Tags: no-fasttest, no-replicated-database, no-llvm-coverage
# Tag no-fasttest: Kafka is not available in fast tests
# Tag no-replicated-database: the test uses a single-partition topic, and multiple replicas compete for partition assignment
# Tag no-llvm-coverage: Kafka consumer is too slow under coverage instrumentation, consumer group rebalancing times out

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

KAFKA_TOPIC=$(echo "${DATASTORE_TEST_UNIQUE_NAME}" | tr '_' '-')
KAFKA_GROUP="${DATASTORE_TEST_UNIQUE_NAME}_group"
KAFKA_BROKER="127.0.0.1:9092"
KEEPER_PATH="/datastore/test/${DATASTORE_TEST_UNIQUE_NAME}"

cleanup()
{
    local exit_code=$?

    trap - EXIT INT TERM
    set +e

    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS ${DATASTORE_TEST_UNIQUE_NAME}_mv" 2>/dev/null
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS ${DATASTORE_TEST_UNIQUE_NAME}_dst" 2>/dev/null
    $DATASTORE_CLIENT -q "DROP TABLE IF EXISTS ${DATASTORE_TEST_UNIQUE_NAME}_kafka" 2>/dev/null
    timeout 10 rpk topic delete $KAFKA_TOPIC --brokers $KAFKA_BROKER > /dev/null 2>&1

    exit $exit_code
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Create topic
rpk topic create $KAFKA_TOPIC -p 1 --brokers $KAFKA_BROKER > /dev/null 2>&1 && echo "Created topic."

# Produce first batch
for i in $(seq 1 3); do
    echo "{\"id\": $i, \"data\": \"batch1_$i\"}"
done | timeout 30 rpk topic produce $KAFKA_TOPIC --brokers $KAFKA_BROKER > /dev/null 2>&1

# Create Kafka2 engine table (with keeper path for offset storage)
$DATASTORE_CLIENT --allow_experimental_kafka_offsets_storage_in_keeper 1 -q "
    CREATE TABLE ${DATASTORE_TEST_UNIQUE_NAME}_kafka (id UInt64, data String)
    ENGINE = Kafka
    SETTINGS kafka_broker_list = '$KAFKA_BROKER',
             kafka_topic_list = '$KAFKA_TOPIC',
             kafka_group_name = '$KAFKA_GROUP',
             kafka_format = 'JSONEachRow',
             kafka_max_block_size = 100,
             kafka_keeper_path = '$KEEPER_PATH',
             kafka_replica_name = 'r1';
"

# Create destination table
$DATASTORE_CLIENT -q "
    CREATE TABLE ${DATASTORE_TEST_UNIQUE_NAME}_dst (id UInt64, data String)
    ENGINE = MergeTree ORDER BY id;
"

# Create materialized view
$DATASTORE_CLIENT -q "
    CREATE MATERIALIZED VIEW ${DATASTORE_TEST_UNIQUE_NAME}_mv TO ${DATASTORE_TEST_UNIQUE_NAME}_dst AS
    SELECT * FROM ${DATASTORE_TEST_UNIQUE_NAME}_kafka;
"

# Wait for first batch (Kafka2 with keeper path needs extra startup time for Keeper coordination)
for i in $(seq 1 120); do
    count=$($DATASTORE_CLIENT -q "SELECT count() FROM ${DATASTORE_TEST_UNIQUE_NAME}_dst SETTINGS max_execution_time=5" 2>/dev/null || echo 0)
    if [ "$count" -ge 3 ]; then
        break
    fi
    sleep 1
done

echo "--- After first batch ---"
$DATASTORE_CLIENT -q "SELECT id, data FROM ${DATASTORE_TEST_UNIQUE_NAME}_dst ORDER BY id"

# Produce second batch
for i in $(seq 4 6); do
    echo "{\"id\": $i, \"data\": \"batch2_$i\"}"
done | timeout 30 rpk topic produce $KAFKA_TOPIC --brokers $KAFKA_BROKER > /dev/null 2>&1

# Wait for second batch
for i in $(seq 1 120); do
    count=$($DATASTORE_CLIENT -q "SELECT count() FROM ${DATASTORE_TEST_UNIQUE_NAME}_dst SETTINGS max_execution_time=5" 2>/dev/null || echo 0)
    if [ "$count" -ge 6 ]; then
        break
    fi
    sleep 1
done

echo "--- After second batch ---"
$DATASTORE_CLIENT -q "SELECT id, data FROM ${DATASTORE_TEST_UNIQUE_NAME}_dst ORDER BY id"
