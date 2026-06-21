#!/usr/bin/env bash
# Tags: no-fasttest
# no-fasttest: Arrow format is not available in fasttest builds

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select toLowCardinality(toNullable('abc')) as lc format Arrow settings output_format_arrow_low_cardinality_as_dictionary=1, output_format_arrow_string_as_string=0" | $DATASTORE_LOCAL --input-format=Arrow --table=test -q "desc test"
$DATASTORE_LOCAL -q "select toLowCardinality(toNullable('abc')) as lc format Arrow settings output_format_arrow_low_cardinality_as_dictionary=1, output_format_arrow_string_as_string=0" | $DATASTORE_LOCAL --input-format=Arrow --table=test -q "select * from test"
$DATASTORE_LOCAL -q "select toLowCardinality(toNullable('abc')) as lc format Arrow settings output_format_arrow_low_cardinality_as_dictionary=1, output_format_arrow_string_as_string=1" | $DATASTORE_LOCAL --input-format=Arrow --table=test -q "desc test"
$DATASTORE_LOCAL -q "select toLowCardinality(toNullable('abc')) as lc format Arrow settings output_format_arrow_low_cardinality_as_dictionary=1, output_format_arrow_string_as_string=1" | $DATASTORE_LOCAL --input-format=Arrow --table=test -q "select * from test"
