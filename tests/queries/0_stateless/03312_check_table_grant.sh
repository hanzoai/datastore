#!/usr/bin/env bash
# Tags: no-fasttest, no-parallel

DATASTORE_CLIENT_SERVER_LOGS_LEVEL='fatal'

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_CLIENT "
DROP TABLE IF EXISTS cheque;
CREATE TABLE cheque (s String) ORDER BY s;
INSERT INTO cheque VALUES ('Check how the cheque checks out on the checkerboard.');

CHECK TABLE cheque SETTINGS check_query_single_value_result = 1;
SELECT * FROM cheque;

CREATE USER test_03312;
GRANT SELECT ON ${DATASTORE_DATABASE}.cheque TO test_03312;
"

$DATASTORE_CLIENT --user test_03312 "
SELECT * FROM cheque;
"

$DATASTORE_CLIENT --user test_03312 "
CHECK TABLE cheque SETTINGS check_query_single_value_result = 1;
" 2>&1 | grep -o -F 'ACCESS_DENIED'

$DATASTORE_CLIENT "
GRANT CHECK ON ${DATASTORE_DATABASE}.cheque TO test_03312;
"

$DATASTORE_CLIENT --user test_03312 "
CHECK TABLE cheque SETTINGS check_query_single_value_result = 1;
"

$DATASTORE_CLIENT "
DROP TABLE cheque;
DROP USER test_03312;
"
