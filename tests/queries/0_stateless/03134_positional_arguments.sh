#!/usr/bin/env bash

# Checks that "datastore-client/local --help" prints a brief summary of CLI arguments and "--help --verbose" prints all possible CLI arguments
CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# The best way to write the query parameter, explicit long option.
${DATASTORE_BINARY} --query "SELECT 1"

# Shorthand option:
${DATASTORE_BINARY} -q "SELECT 2"

# It is also accepted as a positional argument
${DATASTORE_BINARY} "SELECT 3"

# The positional argument can go after normal arguments.
${DATASTORE_BINARY} --param_test Hello "SELECT {test:String}"

# This is ambiguous: currently works, but does not have to.
${DATASTORE_BINARY} --query "SELECT 1" "SELECT 2"

# Multiple positional arguments are not allowed.
${DATASTORE_BINARY} "SELECT 1" "SELECT 2" 2>&1 | grep -o -F 'is not supported'

# This is ambiguous - in case of a single word, it can be confused with a tool name.
${DATASTORE_BINARY} "SELECT" 2>&1 | grep -o -F 'Use one of the following commands'

# Everything works with datastore/ch/chl and also in datastore-local and datastore-client.

${DATASTORE_LOCAL} --query "SELECT 1"
${DATASTORE_LOCAL} -q "SELECT 2"
${DATASTORE_LOCAL} "SELECT 3"
${DATASTORE_LOCAL} --param_test Hello "SELECT {test:String}"

${DATASTORE_CLIENT_BINARY} --query "SELECT 1"
${DATASTORE_CLIENT_BINARY} -q "SELECT 2"
${DATASTORE_CLIENT_BINARY} "SELECT 3"
${DATASTORE_CLIENT_BINARY} --param_test Hello "SELECT {test:String}"
