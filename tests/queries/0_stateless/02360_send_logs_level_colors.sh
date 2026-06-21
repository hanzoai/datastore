#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATASTORE_CLIENT_SERVER_LOGS_LEVEL=trace

# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

file_name="${DATASTORE_TMP}/res_${DATASTORE_DATABASE}.log"

# Run query via expect to make isatty() return true
function run()
{
    command=$1
    expect << EOF
log_user 0
set timeout 60
match_max 100000

spawn bash -c "$command"
expect 1
EOF

    grep -F $'\x1b' "$file_name" && cat "$file_name" || echo "ASCII text"
}

run "$DATASTORE_CLIENT -q 'SELECT 1' 2>$file_name"
run "$DATASTORE_CLIENT -q 'SELECT 1' --server_logs_file=$file_name"
run "$DATASTORE_CLIENT -q 'SELECT 1' --server_logs_file=- >$file_name"

rm -f "$file_name"
