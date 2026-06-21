#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

set -e

touch "${DATASTORE_TMP}"/empty.tsv
$DATASTORE_CLIENT --query="SELECT count() FROM data" --external --file="${DATASTORE_TMP}"/empty.tsv --name=data --types=UInt32
rm "${DATASTORE_TMP}"/empty.tsv

echo -n | $DATASTORE_CLIENT --query="SELECT count() FROM data" --external --file=- --name=data --types=UInt32
echo | $DATASTORE_CLIENT --query="SELECT count() FROM data" --external --file=- --name=data --types=String
