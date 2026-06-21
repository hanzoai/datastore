#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# datastore-local has --input-format and --output-format parameters,
# and also the --format parameter which is the default for both input and output formats, but has less preference.

# datastore-client does not have the --input-format parameter.
# However, it accepts both --format and --output-format for convenience.

${DATASTORE_LOCAL} --output-format Markdown --query "SELECT 'Hello, world' AS x"
${DATASTORE_CLIENT} --output-format Markdown --query "SELECT 'Hello, world' AS x"
${DATASTORE_LOCAL} --format Markdown --query "SELECT 'Hello, world' AS x"
${DATASTORE_CLIENT} --format Markdown --query "SELECT 'Hello, world' AS x"
${DATASTORE_LOCAL} --vertical --query "SELECT 'Hello, world' AS x"
${DATASTORE_CLIENT} --vertical --query "SELECT 'Hello, world' AS x"
${DATASTORE_LOCAL} --query "SELECT 'Hello, world' AS x"
${DATASTORE_CLIENT} --query "SELECT 'Hello, world' AS x"
