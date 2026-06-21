#!/usr/bin/env bash
# Tags: long

set -eu

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

mkdir -p ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/
rm -rf ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME:?}/*

for i in {1..20}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt
done

${DATASTORE_CLIENT} --query "drop table if exists file_log;"
${DATASTORE_CLIENT} --query "create table file_log(k UInt8, v UInt8) engine=FileLog('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/', 'CSV');"

${DATASTORE_CLIENT} --query "drop table if exists mv;"
${DATASTORE_CLIENT} --query "create Materialized View mv engine=MergeTree order by k as select * from file_log;"

function count()
{
	COUNT=$(${DATASTORE_CLIENT} --query "select count() from mv;")
	echo $COUNT
}

while true; do
	[[ $(count) == 20 ]] && break
	sleep 1
done

${DATASTORE_CLIENT} --query "select * from mv order by k;"

cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/b.txt

# touch does not change file content, no event
touch ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt

cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/c.txt
cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/d.txt

for i in {100..120}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/d.txt
done

while true; do
	[[ $(count) == 101 ]] && break
	sleep 1
done

${DATASTORE_CLIENT} --query "select * from mv order by k;"

${DATASTORE_CLIENT} --query "drop table mv;"
${DATASTORE_CLIENT} --query "drop table file_log;"

rm -rf ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME:?}
