#!/usr/bin/env bash
# Tags: no-ordinary-database, use-rocksdb, no-random-settings, no-msan
# msan: too slow

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Normal importing, as we only insert 1000 rows, so it should be in memtable
${DATASTORE_CLIENT} --query "CREATE TABLE IF NOT EXISTS rocksdb_worm (key UInt64, value UInt64) ENGINE = EmbeddedRocksDB() PRIMARY KEY key SETTINGS optimize_for_bulk_insert = 0;"
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number, number+1 FROM numbers(1000) SETTINGS optimize_trivial_insert_select = 1;"
${DATASTORE_CLIENT} --query "SELECT sum(value) FROM system.rocksdb WHERE database = currentDatabase() AND table = 'rocksdb_worm' AND name = 'no.file.opens';" # should be 0 because all data is still in memtable
${DATASTORE_CLIENT} --query "SELECT count() FROM rocksdb_worm;"

# Enabling bulk insertion
${DATASTORE_CLIENT} --query "ALTER TABLE rocksdb_worm MODIFY SETTING optimize_for_bulk_insert = 1;"

# Testing that key serialization is identical w. and w/o bulk sink
${DATASTORE_CLIENT} --query "TRUNCATE TABLE rocksdb_worm;"
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number, number+2 FROM numbers(1000) SETTINGS optimize_trivial_insert_select = 1;" # should override previous keys
${DATASTORE_CLIENT} --query "SELECT count() FROM rocksdb_worm WHERE value = key + 2;"

# With bulk insertion, there is no memtable, so a small insert should create a new file
${DATASTORE_CLIENT} --query "TRUNCATE TABLE rocksdb_worm;"
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number, number+1 FROM numbers(1000) SETTINGS optimize_trivial_insert_select = 1;"
${DATASTORE_CLIENT} --query "SELECT sum(value) FROM system.rocksdb WHERE database = currentDatabase() AND table = 'rocksdb_worm' AND name = 'no.file.opens';" # should be 1
${DATASTORE_CLIENT} --query "SELECT count() FROM rocksdb_worm;"

# Testing insert with multiple sinks and fixed block size
${DATASTORE_CLIENT} --query "TRUNCATE TABLE rocksdb_worm;"
# Must set both max_threads and max_insert_threads to 2 to make sure there is only two sinks
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number, number+1 FROM numbers_mt(1000000) SETTINGS max_threads = 2, max_insert_threads = 2, max_block_size = 10000, min_insert_block_size_rows = 0, min_insert_block_size_bytes = 0, insert_deduplication_token = '', optimize_trivial_insert_select = 1;"
${DATASTORE_CLIENT} --query "SELECT sum(value) IN (1, 2) FROM system.rocksdb WHERE database = currentDatabase() AND table = 'rocksdb_worm' AND name = 'no.file.opens';" # should be not more than 2 because default bulk sink size is ~1M rows / SST file.
${DATASTORE_CLIENT} --query "SELECT count() FROM rocksdb_worm;"

# Testing insert with duplicated keys
${DATASTORE_CLIENT} --query "TRUNCATE TABLE rocksdb_worm;"
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number % 1000, number+1 FROM numbers_mt(1000000) SETTINGS max_block_size = 100000, max_insert_threads = 1, optimize_trivial_insert_select = 1;"
${DATASTORE_CLIENT} --query "SELECT count() FROM rocksdb_worm;"
${DATASTORE_CLIENT} --query "SELECT * FROM rocksdb_worm WHERE key = 0;" # should be the latest value - 999001


# Testing insert with multiple threads
${DATASTORE_CLIENT} --query "TRUNCATE TABLE rocksdb_worm;"
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number, number+1 FROM numbers_mt(1000000) SETTINGS optimize_trivial_insert_select = 1" &
${DATASTORE_CLIENT} --query "INSERT INTO rocksdb_worm SELECT number, number+1 FROM numbers_mt(1000000) SETTINGS optimize_trivial_insert_select = 1" &
wait
${DATASTORE_CLIENT} --query "SELECT count() FROM rocksdb_worm;"
