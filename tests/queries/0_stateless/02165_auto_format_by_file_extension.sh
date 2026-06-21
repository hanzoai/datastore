#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

[ -e "${DATASTORE_TMP}"/hello.csv ] && rm "${DATASTORE_TMP}"/hello.csv
[ -e "${DATASTORE_TMP}"/world.csv.gz ] && rm "${DATASTORE_TMP}"/world.csv.gz
[ -e "${DATASTORE_TMP}"/hello.world.csv ] && rm "${DATASTORE_TMP}"/hello.world.csv
[ -e "${DATASTORE_TMP}"/hello.world.csv.xz ] && rm "${DATASTORE_TMP}"/hello.world.csv.xz
[ -e "${DATASTORE_TMP}"/.htaccess.json ] && rm "${DATASTORE_TMP}"/.htaccess.json
[ -e "${DATASTORE_TMP}"/example.com. ] && rm "${DATASTORE_TMP}"/example.com.
[ -e "${DATASTORE_TMP}"/museum...protobuf ] && rm "${DATASTORE_TMP}"/museum...protobuf

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS 02165_out_tb;"
${DATASTORE_CLIENT} --query "CREATE TABLE 02165_out_tb (id UInt64, name String) Engine=Memory;"
${DATASTORE_CLIENT} --query "INSERT INTO 02165_out_tb Values(1, 'one'), (2, 'tow');"

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS 02165_in_tb;"
${DATASTORE_CLIENT} --query "CREATE TABLE 02165_in_tb (id UInt64, name String) Engine=Memory;"


${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/hello.csv';"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/hello.csv' FORMAT CSV;"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"

${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/world.csv.gz';"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/world.csv.gz' COMPRESSION 'gz' FORMAT CSV;"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"

${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/hello.world.csv';"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/hello.world.csv' FORMAT CSV;"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"

${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/hello.world.csv.xz';"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/hello.world.csv.xz' COMPRESSION 'xz' FORMAT CSV;"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"

${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/example.com.';"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/example.com.' FORMAT TabSeparated;"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"

${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/museum...JSONEachRow';"
${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/museum...JSONEachRow';"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"

${DATASTORE_CLIENT} --query "INSERT INTO TABLE 02165_in_tb FROM INFILE '${DATASTORE_TMP}/world.csv.gz';"
${DATASTORE_CLIENT} --query "SELECT * FROM 02165_in_tb;"
${DATASTORE_CLIENT} --query "TRUNCATE TABLE 02165_in_tb;"


${DATASTORE_CLIENT} --query "SELECT * FROM 02165_out_tb INTO OUTFILE '${DATASTORE_TMP}/.htaccess.json';"
head -n 26 ${DATASTORE_TMP}/.htaccess.json

${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS 02165_out_tb;"
${DATASTORE_CLIENT} --query "DROP TABLE IF EXISTS 02165_in_tb;"

rm "${DATASTORE_TMP}"/hello.csv
rm "${DATASTORE_TMP}"/world.csv.gz
rm "${DATASTORE_TMP}"/hello.world.csv
rm "${DATASTORE_TMP}"/hello.world.csv.xz
rm "${DATASTORE_TMP}"/.htaccess.json
rm "${DATASTORE_TMP}"/example.com.
rm "${DATASTORE_TMP}"/museum...JSONEachRow
