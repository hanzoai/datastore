#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

[ -e "${DATASTORE_TMP}"/test_infile_parallel.gz ] && rm "${DATASTORE_TMP}"/test_infile_parallel.gz
[ -e "${DATASTORE_TMP}"/test_infile_parallel ] && rm "${DATASTORE_TMP}"/test_infile_parallel
[ -e "${DATASTORE_TMP}"/test_infile_parallel ] && rm "${DATASTORE_TMP}"/test_infile_parallel_1
[ -e "${DATASTORE_TMP}"/test_infile_parallel ] && rm "${DATASTORE_TMP}"/test_infile_parallel_2
[ -e "${DATASTORE_TMP}"/test_infile_parallel ] && rm "${DATASTORE_TMP}"/test_infile_parallel_3

echo -e "102\t2" > "${DATASTORE_TMP}"/test_infile_parallel
echo -e "102\tsecond" > "${DATASTORE_TMP}"/test_infile_parallel_1
echo -e "103\tfirst" > "${DATASTORE_TMP}"/test_infile_parallel_2
echo -e "103" > "${DATASTORE_TMP}"/test_infile_parallel_3

gzip "${DATASTORE_TMP}"/test_infile_parallel

${DATASTORE_CLIENT} <<EOF
DROP TABLE IF EXISTS test_infile_parallel;
CREATE TABLE test_infile_parallel (Id Int32,Value Enum('first' = 1, 'second' = 2)) ENGINE=Memory();
SET input_format_allow_errors_num=1;
INSERT INTO test_infile_parallel FROM INFILE '${DATASTORE_TMP}/test_infile_parallel*' FORMAT TSV;
SELECT count() FROM test_infile_parallel WHERE Value='first';
SELECT count() FROM test_infile_parallel WHERE Value='second';
EOF

# Error code is 27 (DB::ParsingException). It is not ignored.
${DATASTORE_CLIENT}  -m --query "DROP TABLE IF EXISTS test_infile_parallel;
CREATE TABLE test_infile_parallel (Id Int32,Value Enum('first' = 1, 'second' = 2)) ENGINE=Memory();
SET input_format_allow_errors_num=0;
INSERT INTO test_infile_parallel FROM INFILE '${DATASTORE_TMP}/test_infile_parallel*' FORMAT TSV;
" 2>&1 | grep -q "27" && echo "Correct" || echo 'Fail'

${DATASTORE_LOCAL} <<EOF
DROP TABLE IF EXISTS test_infile_parallel; 
SET input_format_allow_errors_num=1;
CREATE TABLE test_infile_parallel (Id Int32,Value Enum('first' = 1, 'second' = 2)) ENGINE=Memory(); 
INSERT INTO test_infile_parallel FROM INFILE '${DATASTORE_TMP}/test_infile_parallel*' FORMAT TSV;
SELECT count() FROM test_infile_parallel WHERE Value='first';
SELECT count() FROM test_infile_parallel WHERE Value='second';
EOF
