#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_LOCAL} --query "SELECT * FROM (SELECT 'ALTER TABLE src' AS query, 123 AS query_duration_ms) INTO OUTFILE '${DATASTORE_TMP}/query_log.tsv.zst' FORMAT TSVWithNames"
${DATASTORE_LOCAL} --query "
SELECT *
FROM '${DATASTORE_TMP}/query_log.tsv.zst'
WHERE query_duration_ms = (
    SELECT max(query_duration_ms)
    FROM '${DATASTORE_TMP}/query_log.tsv.zst'
    WHERE query LIKE 'ALTER TABLE src%'
)
LIMIT 1
"

${DATASTORE_CLIENT} --query "
DROP TABLE IF EXISTS t0;
CREATE TABLE t0 (c0 Int) ENGINE = Memory();
INSERT INTO FUNCTION file('${DATASTORE_DATABASE}.values', 'Values') SELECT * FROM (SELECT 1 FROM remote('${DATASTORE_HOST}:${DATASTORE_PORT_TCP}', currentDatabase(), 't0') x) x;
DROP TABLE t0;
"
