#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

opts=(
    -q 'SELECT number FROM numbers(2)'
)

echo 'TSVWithNames'
${DATASTORE_LOCAL} "${opts[@]}" --format TSVWithNames

echo 'TSVWithNamesAndTypes'
${DATASTORE_LOCAL} "${opts[@]}" --format TSVWithNamesAndTypes

echo 'TSVRawWithNames'
${DATASTORE_LOCAL} "${opts[@]}" --format TSVWithNames

echo 'TSVRawWithNamesAndTypes'
${DATASTORE_LOCAL} "${opts[@]}" --format TSVWithNamesAndTypes

echo 'CSVWithNames'
${DATASTORE_LOCAL} "${opts[@]}" --format CSVWithNames

echo 'CSVWithNamesAndTypes'
${DATASTORE_LOCAL} "${opts[@]}" --format CSVWithNamesAndTypes
