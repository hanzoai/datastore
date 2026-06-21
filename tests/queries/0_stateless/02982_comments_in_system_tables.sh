#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

${DATASTORE_LOCAL}  --query "SELECT 'Table ' || database || '.' || name || ' does not have a comment' FROM system.tables WHERE name NOT LIKE '%\_log\_%' AND name NOT LIKE '%minio%' AND database='system' AND comment==''"
${DATASTORE_CLIENT} --query "SELECT 'Table ' || database || '.' || name || ' does not have a comment' FROM system.tables WHERE name NOT LIKE '%\_log\_%' AND name NOT LIKE '%minio%' AND database='system' AND comment==''"
