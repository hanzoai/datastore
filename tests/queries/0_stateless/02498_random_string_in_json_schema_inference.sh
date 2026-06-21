#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select randomString(100) as s format JSONEachRow" | $DATASTORE_LOCAL -q "desc test" --table='test' --input-format='JSONEachRow' 
