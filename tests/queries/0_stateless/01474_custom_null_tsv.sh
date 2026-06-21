#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS tsv_custom_null";
$DATASTORE_CLIENT --query="CREATE TABLE tsv_custom_null (id Nullable(UInt32)) ENGINE = Memory";

$DATASTORE_CLIENT --query="INSERT INTO tsv_custom_null VALUES (NULL)";

$DATASTORE_CLIENT --format_tsv_null_representation='MyNull' --query="SELECT * FROM tsv_custom_null FORMAT TSV";

$DATASTORE_CLIENT --query="DROP TABLE tsv_custom_null";

