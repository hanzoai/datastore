#!/usr/bin/env bash
# Tags: no-fasttest, no-msan
# Tag no-fasttest: Requires libs
# Tag no-msan: DeltaKernel is not compiled with msan

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

USER="user_3611_${DATASTORE_DATABASE}"

function cleanup()
{
    ${DATASTORE_CLIENT} -q "DROP USER IF EXISTS ${USER}"
}
trap cleanup EXIT

FILE="${USER_FILES_PATH}/file_that_does_not_exist.csv"

function run_table_functions()
{
    EXPECTED_ERROR=$1

    for table_function in "file" "icebergLocal" "deltaLakeLocal"; do
        ${DATASTORE_CLIENT} --user="${USER}" --query "SELECT * FROM ${table_function}('${FILE}') -- { serverError ${EXPECTED_ERROR} }"
    done
}

${DATASTORE_CLIENT} -q "CREATE USER ${USER}"
${DATASTORE_CLIENT} -q "GRANT CREATE TEMPORARY TABLE ON *.* TO ${USER};"
run_table_functions "ACCESS_DENIED"
${DATASTORE_CLIENT} -q "GRANT FILE ON *.* TO ${USER};"
run_table_functions "FILE_DOESNT_EXIST, DELTA_KERNEL_ERROR, CANNOT_STAT"
${DATASTORE_CLIENT} -q "REVOKE FILE ON *.* FROM ${USER};"
run_table_functions "ACCESS_DENIED"