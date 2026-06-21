#!/usr/bin/env bash
set -e

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_LOCAL} --query "create table test engine Log as select 1 a"

# Should not see the table created by the previous instance
if ${DATASTORE_LOCAL} --query "select * from test" 2>/dev/null
then
 exit 1
fi

