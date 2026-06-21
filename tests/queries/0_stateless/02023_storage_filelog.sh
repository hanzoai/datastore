#!/usr/bin/env bash

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

${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/b.txt

${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

for i in {100..120}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt
done

# touch does not change file content, no event
touch ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt

cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/c.txt
cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/d.txt
cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/e.txt
mv ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/b.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/j.txt

rm ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/d.txt

sleep 2

${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

${DATASTORE_CLIENT} --query "detach table file_log;"
cp ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/e.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/f.txt
mv ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/e.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/g.txt
mv ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/c.txt ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/h.txt
for i in {150..200}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/h.txt
done
for i in {200..250}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/i.txt
done
${DATASTORE_CLIENT} --query "attach table file_log;"

${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

${DATASTORE_CLIENT} --query "detach table file_log;"
${DATASTORE_CLIENT} --query "attach table file_log;"

# should no records return
${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

truncate ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/a.txt --size 0

sleep 2

# exception happend
${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;" 2>&1 | grep -q "Code: 33" && echo 'OK' || echo 'FAIL'

${DATASTORE_CLIENT} --query "drop table file_log;"

rm -rf ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME:?}
