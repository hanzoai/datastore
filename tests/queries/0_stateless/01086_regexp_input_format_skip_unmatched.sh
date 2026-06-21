#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS regexp";
$DATASTORE_CLIENT --query="CREATE TABLE regexp (id UInt32, string String) ENGINE = Memory";

echo 'id: 1 string: str1
id: 2 string: str2
id=3, string=str3
id: 4 string: str4' | $DATASTORE_CLIENT --query="INSERT INTO regexp SETTINGS format_regexp='id: (.+?) string: (.+?)', format_regexp_escaping_rule='Escaped', format_regexp_skip_unmatched=1 FORMAT Regexp";

$DATASTORE_CLIENT --query="SELECT * FROM regexp";
$DATASTORE_CLIENT --query="DROP TABLE regexp";
 
