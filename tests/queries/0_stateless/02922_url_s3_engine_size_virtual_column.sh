#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT -q "select _file, _size from url('http://localhost:11111/test/{a,b,c}.tsv', 'One') order by _file"
$DATASTORE_CLIENT -q "select _file, _size from url('http://localhost:11111/test/{a,b,c}.tsv', 'One') order by _file"

$DATASTORE_CLIENT -q "select _file, _size from s3('http://localhost:11111/test/{a,b,c}.tsv', 'One') order by _file"
$DATASTORE_CLIENT -q "select _file, _size from s3('http://localhost:11111/test/{a,b,c}.tsv', 'One') order by _file"

