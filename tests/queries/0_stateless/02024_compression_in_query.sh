#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

#____________________CLIENT__________________
# clear files from previous tests.
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output.gz ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output.gz
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz.gz ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz.gz
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz_to_decomp ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz_to_decomp
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output_to_decomp ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output_to_decomp

# create files using compression method and without it to check that both queries work correct
${DATASTORE_CLIENT} --query "SELECT * FROM (SELECT 'Hello, World! From client.') INTO OUTFILE '${DATASTORE_TMP}/test_comp_for_input_and_output.gz' FORMAT TabSeparated;"
${DATASTORE_CLIENT} --query "SELECT * FROM (SELECT 'Hello, World! From client.') INTO OUTFILE '${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz' COMPRESSION 'GZ' FORMAT TabSeparated;"

# check content of files
cp ${DATASTORE_TMP}/test_comp_for_input_and_output.gz ${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp.gz
gunzip ${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp.gz
cat ${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp

cp ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp.gz
gunzip ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp.gz
cat ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp

# create table to check inserts
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_compression_keyword;"
${DATASTORE_CLIENT} --query "CREATE TABLE test_compression_keyword (text String) Engine=Memory;"

# insert them
${DATASTORE_CLIENT} --query "INSERT INTO TABLE test_compression_keyword FROM INFILE '${DATASTORE_TMP}/test_comp_for_input_and_output.gz' FORMAT TabSeparated;"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE test_compression_keyword FROM INFILE '${DATASTORE_TMP}/test_comp_for_input_and_output.gz' COMPRESSION 'gz' FORMAT TabSeparated;"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE test_compression_keyword FROM INFILE '${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz' COMPRESSION 'gz' FORMAT TabSeparated;"

# check result
${DATASTORE_CLIENT} --query "SELECT * FROM test_compression_keyword;"

# delete all created elements
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp"
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output.gz"
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp"
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS test_compression_keyword;"

#____________________LOCAL__________________
# clear files from previous tests.
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output.gz ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output.gz
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz
[ -e "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz.gz ] && rm "${DATASTORE_TMP}"/test_comp_for_input_and_output_without_gz.gz

# create files using compression method and without it to check that both queries work correct
${DATASTORE_LOCAL} --query "SELECT * FROM (SELECT 'Hello, World! From local.') INTO OUTFILE '${DATASTORE_TMP}/test_comp_for_input_and_output.gz' FORMAT TabSeparated;"
${DATASTORE_LOCAL} --query "SELECT * FROM (SELECT 'Hello, World! From local.') INTO OUTFILE '${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz' COMPRESSION 'GZ' FORMAT TabSeparated;"

# check content of files
cp ${DATASTORE_TMP}/test_comp_for_input_and_output.gz ${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp.gz
gunzip ${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp.gz
cat ${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp

cp ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp.gz
gunzip ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp.gz
cat ${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp

# create table to check inserts
${DATASTORE_LOCAL} --query "
DROP TABLE IF EXISTS test_compression_keyword;
CREATE TABLE test_compression_keyword (text String) Engine=Memory;
INSERT INTO TABLE test_compression_keyword FROM INFILE '${DATASTORE_TMP}/test_comp_for_input_and_output.gz' FORMAT TabSeparated;
INSERT INTO TABLE test_compression_keyword FROM INFILE '${DATASTORE_TMP}/test_comp_for_input_and_output.gz' COMPRESSION 'gz' FORMAT TabSeparated;
INSERT INTO TABLE test_compression_keyword FROM INFILE '${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz' COMPRESSION 'gz' FORMAT TabSeparated;
SELECT * FROM test_compression_keyword;
"

# delete all created elements
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output_to_decomp"
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output.gz"
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz_to_decomp"
rm -f "${DATASTORE_TMP}/test_comp_for_input_and_output_without_gz"
