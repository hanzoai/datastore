#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS custom_separated"
$DATASTORE_CLIENT --query="CREATE TABLE custom_separated (n UInt64, d Date, s String) ENGINE = Memory()"
$DATASTORE_CLIENT --query="INSERT INTO custom_separated VALUES (0, '2019-09-24', 'hello'), (1, '2019-09-25', 'world'), (2, '2019-09-26', 'custom'), (3, '2019-09-27', 'separated')"

$DATASTORE_CLIENT --query="SELECT * FROM custom_separated ORDER BY n FORMAT CustomSeparated SETTINGS \
format_custom_escaping_rule = 'CSV', \
format_custom_field_delimiter = '\t|\t', \
format_custom_row_before_delimiter = '||', \
format_custom_row_after_delimiter = '\t||', \
format_custom_row_between_delimiter = '\n', \
format_custom_result_before_delimiter = '========== result ==========\n', \
format_custom_result_after_delimiter = '\n============================\n'"

$DATASTORE_CLIENT --query="TRUNCATE TABLE custom_separated"

echo '0, "2019-09-24", "hello"
1, 2019-09-25, "world"
2, "2019-09-26", custom
3, 2019-09-27, separated
end' | $DATASTORE_CLIENT --query="INSERT INTO custom_separated SETTINGS \
format_custom_escaping_rule = 'CSV', \
format_custom_field_delimiter = ', ', \
format_custom_row_after_delimiter = '\n', \
format_custom_row_between_delimiter = '', \
format_custom_result_after_delimiter = 'end\n'
FORMAT CustomSeparated"

$DATASTORE_CLIENT --query="SELECT * FROM custom_separated ORDER BY n FORMAT CSV"

$DATASTORE_CLIENT --query="DROP TABLE custom_separated"

echo -ne "a,b\nc,d\n" | $DATASTORE_LOCAL --structure "a String, b String"  \
  --input-format CustomSeparated --format_custom_escaping_rule=Escaped \
  --format_custom_field_delimiter=',' --format_custom_row_after_delimiter=$'\n' -q 'select * from table' \
  2>&1| grep -Fac "'Escaped' serialization requires delimiter"
