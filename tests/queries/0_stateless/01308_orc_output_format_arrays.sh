#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS orc";

$DATASTORE_CLIENT --query="CREATE TABLE orc (array1 Array(Int32), array2 Array(Array(Int32))) ENGINE = Memory";

$DATASTORE_CLIENT --query="INSERT INTO orc VALUES ([1,2,3,4,5], [[1,2], [3,4], [5]]), ([42], [[42, 42], [42]])";

$DATASTORE_CLIENT --query="SELECT * FROM orc FORMAT ORC SETTINGS output_format_orc_compression_method='none'" | md5sum;

$DATASTORE_CLIENT --query="DROP TABLE orc";

