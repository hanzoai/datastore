#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Tests setting 'network_compression_method'

$DATASTORE_CLIENT --network_compression_method='LZ4' --query "SELECT 1"
$DATASTORE_CLIENT --network_compression_method='lz4' --query "SELECT 1.0"
$DATASTORE_CLIENT --network_compression_method='lz4' --query "SELECT 'abc'"

$DATASTORE_CLIENT --network_compression_method='lz4hc' --query "SELECT 1"
$DATASTORE_CLIENT --network_compression_method='lz4hc' --query "SELECT 1.0"
$DATASTORE_CLIENT --network_compression_method='lz4hc' --query "SELECT 'abc'"

$DATASTORE_CLIENT --network_compression_method='zstd' --query "SELECT 1"
$DATASTORE_CLIENT --network_compression_method='zstd' --query "SELECT 1.0"
$DATASTORE_CLIENT --network_compression_method='zstd' --query "SELECT 'abc'"

$DATASTORE_CLIENT --network_compression_method='none' --query "SELECT 1"
$DATASTORE_CLIENT --network_compression_method='none' --query "SELECT 1.0"
$DATASTORE_CLIENT --network_compression_method='none' --query "SELECT 'abc'"

${DATASTORE_CLIENT} --network_compression_method='not_a_codec' --query "select 1" 2>&1 | grep -F -q "BAD_ARGUMENTS" && echo "OK" || echo "FAIL";

#
# -- At this point, the connection parameters are broken and cannot be repaired
# -- Users at least get an error message what is wrong
# SET network_compression_method = 'ZSTD'; -- { clientError BAD_ARGUMENTS }
