#!/usr/bin/env bash
# Tags: no-fasttest, no-shared-merge-tree, no-distributed-cache, no-replicated-database
# Tag no-fasttest: requires Azure
# Tag no-shared-merge-tree: does not support replication
# Tag no-distributed-cache: Not supported auth type
# Tag no-replicated-database: plain rewritable should not be shared between replicas

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

container="cont-$(echo "${DATASTORE_TEST_UNIQUE_NAME}" | tr _ -)"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS 03008_alter_partition"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS 03008_alter_partition_dst"

${DATASTORE_CLIENT} -nm --query "
CREATE TABLE 03008_alter_partition (a Int32, b Int32) ENGINE = MergeTree() PARTITION BY intDiv(a, 20) order by a
SETTINGS disk = disk(
    type = object_storage,
    metadata_type = plain_rewritable,
    object_storage_type = azure_blob_storage,
    name = '${container}',
    path='/var/lib/datastore/disks/${container}/tables',
    container_name = '${container}',
    endpoint = 'http://localhost:10000/devstoreaccount1/${container}/plain-tables',
    account_name = 'devstoreaccount1',
    account_key = 'Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==');
"

${DATASTORE_CLIENT} --query "
INSERT INTO 03008_alter_partition (*) SELECT number, number % 3 FROM numbers_mt(100);
"
${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition DROP PARTITION 0"

${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition DROP PART '1_2_2_0'"

${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition DETACH PARTITION 2"
${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition ATTACH PARTITION 2"
${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition ATTACH PARTITION 2"

${DATASTORE_CLIENT} --query "SELECT count(*) FROM 03008_alter_partition"

${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition DETACH PARTITION 2"
${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition DETACH PARTITION 2"
${DATASTORE_CLIENT} --query "
ALTER TABLE 03008_alter_partition DROP DETACHED PARTITION 2 SETTINGS allow_drop_detached=1
"

${DATASTORE_CLIENT} --query "SELECT count(*) FROM 03008_alter_partition"

${DATASTORE_CLIENT} -nm --query "
CREATE TABLE 03008_alter_partition_dst (a Int32, b Int32) ENGINE = MergeTree() PARTITION BY intDiv(a, 20) order by a
SETTINGS disk = disk(
    type = object_storage,
    metadata_type = plain_rewritable,
    object_storage_type = azure_blob_storage,
    name = '${container}',
    path='/var/lib/datastore/disks/${container}/tables',
    container_name = '${container}',
    endpoint = 'http://localhost:10000/devstoreaccount1/${container}/plain-tables',
    account_name = 'devstoreaccount1',
    account_key = 'Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==');
"
${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition MOVE PARTITION 3 TO TABLE 03008_alter_partition_dst"

${DATASTORE_CLIENT} --query "OPTIMIZE TABLE 03008_alter_partition FINAL"

${DATASTORE_CLIENT} -m --query "
SELECT count(*) FROM 03008_alter_partition;
SELECT count(*) FROM 03008_alter_partition_dst;
"

${DATASTORE_CLIENT} --query "
INSERT INTO 03008_alter_partition_dst (*) SELECT number, number % 5 from numbers_mt(80, 20);
"

${DATASTORE_CLIENT} --query "ALTER TABLE 03008_alter_partition_dst REPLACE PARTITION 4 FROM 03008_alter_partition"

${DATASTORE_CLIENT} --query "OPTIMIZE TABLE 03008_alter_partition_dst FINAL"

${DATASTORE_CLIENT} -m --query "
SELECT count(*) FROM 03008_alter_partition;
SELECT DISTINCT b FROM 03008_alter_partition WHERE a >=80 ORDER BY b;
SELECT count(*) FROM 03008_alter_partition_dst;
SELECT DISTINCT b FROM 03008_alter_partition_dst WHERE a >=80 ORDER BY b
"

${DATASTORE_CLIENT} --query "DROP TABLE 03008_alter_partition_dst SYNC"
${DATASTORE_CLIENT} --query "DROP TABLE 03008_alter_partition SYNC"
