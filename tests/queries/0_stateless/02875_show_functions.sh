#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

diff <($DATASTORE_LOCAL -q "SELECT * from system.functions") \
        <($DATASTORE_LOCAL -q "SHOW FUNCTIONS")

diff <($DATASTORE_LOCAL -q "SELECT * FROM system.functions WHERE name ILIKE 'quantile%'") \
        <($DATASTORE_LOCAL -q "SHOW FUNCTIONS ILIKE 'quantile%'")

diff <($DATASTORE_LOCAL -q "SELECT * FROM system.functions WHERE name LIKE 'median%'") \
	<($DATASTORE_LOCAL -q "SHOW FUNCTIONS LIKE 'median%'")
