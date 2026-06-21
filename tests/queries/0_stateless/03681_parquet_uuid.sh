#!/usr/bin/env bash
# Tags: no-fasttest
# Tag no-fasttest: Depends on Parquet

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_LOCAL} --query "SELECT '01234567-89ab-cdef-aabb-ccddeeff0011'::UUID AS x INTO OUTFILE 'uuid_${DATASTORE_DATABASE}.parquet'"
${DATASTORE_LOCAL} --query "SELECT x::UUID FROM 'uuid_${DATASTORE_DATABASE}.parquet'"
