#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

${DATASTORE_CLIENT} -q "DROP TABLE IF EXISTS data"
${DATASTORE_CLIENT} -q "CREATE TABLE data (key Int) Engine=Memory()"
${DATASTORE_CLIENT} --input_format_parallel_parsing=0 -q "INSERT INTO data SELECT key FROM input('key Int') FORMAT TSV" <<<10
# with '\n...' after the query datastore-client prefer data from the query over data from stdin, and produce very tricky message:
#   Code: 27. DB::Exception: Cannot parse input: expected '\n' before: ' ': (at row 1)
# well for TSV it is ok, but for RowBinary:
#   Code: 33. DB::Exception: Cannot read all data. Bytes read: 1. Bytes expected: 4.
# so check that the exception message contain the data source.
${DATASTORE_CLIENT} --async_insert=0 --input_format_parallel_parsing=0 -q "INSERT INTO data FORMAT TSV
 " <<<2 |& grep -F -c 'data for INSERT was parsed from query'
${DATASTORE_CLIENT} --async_insert=1 --input_format_parallel_parsing=0 -q "INSERT INTO data FORMAT TSV
 " <<<2 |& grep -F -c 'Processing async inserts with both inlined and external data (from stdin or infile) is not supported'
${DATASTORE_CLIENT} -q "SELECT * FROM data"

$DATASTORE_CLIENT -q "DROP TABLE data"
