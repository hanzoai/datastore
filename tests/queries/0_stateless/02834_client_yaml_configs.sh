#!/usr/bin/env bash
# Tags: no-fasttest, no-random-settings

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

pushd "${DATASTORE_TMP}" > /dev/null || exit

echo "max_block_size: 31337" > datastore-client.yaml
${DATASTORE_CLIENT} --query "SELECT getSetting('max_block_size')"
rm datastore-client.yaml

echo "max_block_size: 31338" > datastore-client.yml
${DATASTORE_CLIENT} --query "SELECT getSetting('max_block_size')"
rm datastore-client.yml

echo "<datastore><max_block_size>31339</max_block_size></datastore>" > datastore-client.xml
${DATASTORE_CLIENT} --query "SELECT getSetting('max_block_size')"
rm datastore-client.xml

popd > /dev/null || exit
