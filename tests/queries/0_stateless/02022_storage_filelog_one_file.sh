#!/usr/bin/env bash

set -eu

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


for i in {1..20}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}.txt
done

${DATASTORE_CLIENT} --query "drop table if exists file_log;"
${DATASTORE_CLIENT} --query "create table file_log(k UInt8, v UInt8) engine=FileLog('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}.txt', 'CSV');"

${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

for i in {100..120}
do
	echo $i, $i >> ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}.txt
done

${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

# touch does not change file content, no event
touch ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}.txt
${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

${DATASTORE_CLIENT} --query "detach table file_log;"
${DATASTORE_CLIENT} --query "attach table file_log;"

# should no records return
${DATASTORE_CLIENT} --query "select * from file_log order by k settings stream_like_engine_allow_direct_select=1;"

${DATASTORE_CLIENT} --query "drop table file_log;"

rm -rf ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}.txt
