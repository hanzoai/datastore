#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

tmp_file="$CUR_DIR/03031_$DATASTORE_DATABASE.txt"
tmp_input="$CUR_DIR/03031_${DATASTORE_DATABASE}_in.txt"

echo '# foo (pipe)'
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') select * from input('x String') format LineAsString" <<<foo
cat "$tmp_file"

echo '# foo (file)'
echo 'foo' > "$tmp_input"
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') select * from input('x String') format LineAsString" <"$tmp_input"
cat "$tmp_file"

echo '# !foo'
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') select * from input('x String') where x != 'foo' format LineAsString" <<<foo
cat "$tmp_file"

echo '# bar'
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') select y from input('x String, y String') format TSV" <<<$'foo\tbar'
cat "$tmp_file"

echo '# defaults'
$DATASTORE_LOCAL --input_format_tsv_empty_as_default=1 --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') select y from input('x String, y String DEFAULT \\'bam\\'') format TSV" <<<$'foo\t'
cat "$tmp_file"

echo '# inferred destination table structure'
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'TSV') select * from input('x String') format LineAsString" <"$tmp_input"
cat "$tmp_file"

echo '# direct'
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') format LineAsString" <"$tmp_input"
cat "$tmp_file"

echo '# infile'
$DATASTORE_LOCAL --engine_file_truncate_on_insert=1 -q "insert into function file('$tmp_file', 'LineAsString', 'x String') from infile '$tmp_input' format LineAsString"
cat "$tmp_file"

rm -f "${tmp_file:?}" "${tmp_input:?}"
