#!/usr/bin/env bash
# Tags: no-replicated-database

set -eu

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

rm -rf ${USER_FILES_PATH:?}/${DATASTORE_TEST_UNIQUE_NAME:?}/*
mkdir -p ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/

${DATASTORE_CLIENT} --query "SELECT *, _file FROM file('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir{?/subdir?1/da,2/subdir2?/da}ta/non_existing.csv', CSV);" 2>&1 | grep -q "CANNOT_EXTRACT_TABLE_STRUCTURE" && echo 'OK' || echo 'FAIL'

# Create two files in different directories
mkdir -p ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir1/subdir11/
mkdir -p ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir2/subdir22/

echo 'This is file data1' > ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir1/subdir11/data1.csv
echo 'This is file data2' > ${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir2/subdir22/data2.csv

${DATASTORE_CLIENT} --query "SELECT *, _file FROM file('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir{?/subdir?1/da,2/subdir2?/da}ta1.csv', CSV);"
${DATASTORE_CLIENT} --query "SELECT *, _file FROM file('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir{?/subdir?1/da,2/subdir2?/da}ta2.csv', CSV);"

${DATASTORE_CLIENT} --query "SELECT *, _file FROM file('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir?/{subdir?1/data1,subdir2?/data2}.csv', CSV) WHERE _file == 'data1.csv';"
${DATASTORE_CLIENT} --query "SELECT *, _file FROM file('${USER_FILES_PATH}/${DATASTORE_TEST_UNIQUE_NAME}/dir?/{subdir?1/data1,subdir2?/data2}.csv', CSV) WHERE _file == 'data2.csv';"

rm -rf ${USER_FILES_PATH:?}/${DATASTORE_TEST_UNIQUE_NAME:?}
