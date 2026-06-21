#!/usr/bin/env bash
# Tags: no-parallel

DATASTORE_CLIENT_SERVER_LOGS_LEVEL=none

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} --multiline -q """
DROP USER IF EXISTS user_test_02337;
CREATE USER user_test_02337 IDENTIFIED WITH plaintext_password BY 'user_test_02337';
REVOKE ALL ON *.* FROM user_test_02337;
"""
${DATASTORE_CLIENT} --multiline --user user_test_02337 --password user_test_02337 -q """
SYSTEM CLEAR FILESYSTEM CACHE; -- { serverError 497 }
"""
${DATASTORE_CLIENT} --multiline -q """
GRANT SYSTEM CLEAR FILESYSTEM CACHE ON *.* TO user_test_02337 WITH GRANT OPTION;
"""
${DATASTORE_CLIENT} --multiline --user user_test_02337 --password user_test_02337 -q """
SYSTEM CLEAR FILESYSTEM CACHE;
"""
