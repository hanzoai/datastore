#!/usr/bin/env bash
# Tags: no-parallel

MYHOSTNAME=$(hostname -f)

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_CLIENT} --query "
    DROP USER IF EXISTS dns_fail_1, dns_fail_2;
    CREATE USER dns_fail_1 HOST NAME 'non.existing.host.name', '${MYHOSTNAME}';
    CREATE USER dns_fail_2 HOST NAME '${MYHOSTNAME}', 'non.existing.host.name';"

${DATASTORE_CLIENT} --query "SELECT 1" --user dns_fail_1 --host ${MYHOSTNAME}

${DATASTORE_CLIENT} --query "SELECT 2" --user dns_fail_2 --host ${MYHOSTNAME}

${DATASTORE_CLIENT} --query "DROP USER IF EXISTS dns_fail_1, dns_fail_2"

${DATASTORE_CLIENT} --query "SYSTEM CLEAR DNS CACHE"
