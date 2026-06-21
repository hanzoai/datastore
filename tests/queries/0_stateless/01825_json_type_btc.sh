#!/usr/bin/env bash
# Tags: no-fasttest

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

mkdir -p ${DATASTORE_USER_FILES_UNIQUE}/
rm -rf "${DATASTORE_USER_FILES_UNIQUE:?}"/*
cp $CUR_DIR/data_json/btc_transactions.json ${DATASTORE_USER_FILES_UNIQUE}/

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS btc"

${DATASTORE_CLIENT} -q "CREATE TABLE btc (data JSON) ENGINE = MergeTree ORDER BY tuple()" --enable_json_type 1

${DATASTORE_CLIENT} -q "INSERT INTO btc SELECT * FROM file('${DATASTORE_TEST_UNIQUE_NAME}/btc_transactions.json', 'JSONAsObject')"

${DATASTORE_CLIENT} -q "SELECT count() FROM btc WHERE NOT ignore(*)"
${DATASTORE_CLIENT} -q "SELECT distinct arrayJoin(JSONAllPathsWithTypes(data)) as path from btc order by path"
${DATASTORE_CLIENT} -q "SELECT distinct arrayJoin(JSONAllPathsWithTypes(arrayJoin(data.inputs.:\`Array(JSON)\`))) as path from btc order by path"
${DATASTORE_CLIENT} -q "SELECT distinct arrayJoin(JSONAllPathsWithTypes(arrayJoin(arrayJoin(data.inputs.:\`Array(JSON)\`.prev_out.spending_outpoints.:\`Array(JSON)\`)))) as path from btc order by path"

${DATASTORE_CLIENT} -q "SELECT avg(data.fee.:Int64), median(data.fee.:Int64) FROM btc"

${DATASTORE_CLIENT} -q "SELECT avg(length(data.inputs.:\`Array(JSON)\`.prev_out.spending_outpoints.:\`Array(JSON)\`) AS outpoints_length), median(outpoints_length) FROM btc"

${DATASTORE_CLIENT} -q "SELECT data.out.:\`Array(JSON)\`.spending_outpoints.:\`Array(JSON)\` AS outpoints FROM btc WHERE arrayExists(x -> notEmpty(x), outpoints)"

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS btc"

rm ${DATASTORE_USER_FILES_UNIQUE}/btc_transactions.json
