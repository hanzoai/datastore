#!/usr/bin/env bash

# Test that datastore-local properly handles SYSTEM queries that are not supported
# These queries should throw UNSUPPORTED_METHOD errors instead of LOGICAL_ERROR

set -e

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_LOCAL --query "SYSTEM RELOAD CONFIG; -- { serverError UNSUPPORTED_METHOD }"
$DATASTORE_LOCAL --query "SYSTEM STOP LISTEN HTTP; -- { serverError UNSUPPORTED_METHOD }"
$DATASTORE_LOCAL --query "SYSTEM START LISTEN HTTP; -- { serverError UNSUPPORTED_METHOD }"
$DATASTORE_LOCAL --query "SYSTEM STOP LISTEN TCP; -- { serverError UNSUPPORTED_METHOD }"
$DATASTORE_LOCAL --query "SYSTEM START LISTEN TCP; -- { serverError UNSUPPORTED_METHOD }"


$DATASTORE_LOCAL --query "SYSTEM CLEAR DNS CACHE;"
$DATASTORE_LOCAL --query "SYSTEM CLEAR MARK CACHE;"
$DATASTORE_LOCAL --query "SYSTEM CLEAR UNCOMPRESSED CACHE;"
$DATASTORE_LOCAL --query "SYSTEM CLEAR QUERY CACHE;"
$DATASTORE_LOCAL --query "SYSTEM CLEAR SCHEMA CACHE;"
$DATASTORE_LOCAL --query "SYSTEM CLEAR FORMAT SCHEMA CACHE;"