#!/usr/bin/env bash
# Tags: no-random-settings, no-object-storage, no-replicated-database, no-shared-merge-tree
# Tag no-random-settings: enable after root causing flakiness
# Tag no-replicated-database: plain rewritable should not be shared between replicas

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS writer SYNC"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS reader SYNC"

${DATASTORE_CLIENT} --query "
CREATE TABLE writer (s String) ORDER BY ()
SETTINGS table_disk = true,
  disk = disk(
      name = 03362_writer_${DATASTORE_DATABASE},
      type = object_storage,
      object_storage_type = local,
      metadata_type = plain_rewritable,
      path = 'disks/03362/${DATASTORE_DATABASE}/')
"

${DATASTORE_CLIENT} --query "
CREATE TABLE reader (s String) ORDER BY ()
SETTINGS table_disk = true, refresh_parts_interval = 1,
  disk = disk(
      readonly = true,
      name = 03362_reader_${DATASTORE_DATABASE},
      type = object_storage,
      object_storage_type = local,
      metadata_type = plain_rewritable,
      path = 'disks/03362/${DATASTORE_DATABASE}/')
"

${DATASTORE_CLIENT} --query "INSERT INTO writer VALUES ('Hello')";

while true
do
    ${DATASTORE_CLIENT} --query "SELECT * FROM reader" | grep -F 'Hello' && break;
    sleep 0.1;
done

${DATASTORE_CLIENT} --query "DROP TABLE reader SYNC"
${DATASTORE_CLIENT} --query "DROP TABLE writer SYNC"
