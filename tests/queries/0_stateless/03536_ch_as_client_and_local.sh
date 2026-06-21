#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

DATASTORE_BINARY_CH=${DATASTORE_BINARY/datastore/ch}

# Invocation with unknown tool name prints help:
${DATASTORE_BINARY} test 2>&1 | grep -F 'Use one of the following commands'

# Invocation with --help works the same:
${DATASTORE_BINARY} --help 2>&1 | grep -F 'Use one of the following commands'
${DATASTORE_BINARY_CH} --help 2>&1 | grep -F 'Use one of the following commands'

# This is recognized as datastore-local:
${DATASTORE_BINARY} --query "SELECT engine FROM system.databases WHERE name = currentDatabase()"
${DATASTORE_BINARY_CH} --query "SELECT engine FROM system.databases WHERE name = currentDatabase()"

# This is recognized as datastore-client:
${DATASTORE_BINARY} --host ${DATASTORE_HOST} --port ${DATASTORE_PORT_TCP} --query "SELECT engine FROM system.databases WHERE name = currentDatabase()"
${DATASTORE_BINARY_CH} --query "SELECT engine FROM system.databases WHERE name = currentDatabase()" -h${DATASTORE_HOST} --port=${DATASTORE_PORT_TCP}
