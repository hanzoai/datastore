#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS csv";
$DATASTORE_CLIENT --query="CREATE TABLE csv (s String, n UInt64, d Date) ENGINE = Memory";

echo '"Hello, world"| 123| "2016-01-01"
"Hello, ""world"""| "456"| 2016-01-02|
Hello "world"| 789 |2016-01-03
"Hello
 world"| 100| 2016-01-04|' | $DATASTORE_CLIENT --format_csv_delimiter="|"  --query="INSERT INTO csv FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM csv ORDER BY d";

$DATASTORE_CLIENT --query="DROP TABLE csv";
$DATASTORE_CLIENT --query="CREATE TABLE csv (s String, n UInt64, d Date) ENGINE = Memory";

echo '"Hello, world"; 123; "2016-01-01"
"Hello, ""world"""; "456"; 2016-01-02;
Hello "world"; 789 ;2016-01-03
"Hello
 world"; 100; 2016-01-04;' | $DATASTORE_CLIENT --query="SET format_csv_delimiter=';'; INSERT INTO csv FORMAT CSV";

$DATASTORE_CLIENT --query="SELECT * FROM csv ORDER BY d";
$DATASTORE_CLIENT --format_csv_delimiter=";" --query="SELECT * FROM csv ORDER BY d FORMAT CSV";
$DATASTORE_CLIENT --format_csv_delimiter="/" --query="SELECT * FROM csv ORDER BY d FORMAT CSV";

$DATASTORE_CLIENT --query="DROP TABLE csv";
$DATASTORE_CLIENT --query="CREATE TABLE csv (s1 String, s2 String) ENGINE = Memory";

echo 'abc,def;hello;
hello; world;
"hello ""world""";abc,def;' | $DATASTORE_CLIENT --query="SET format_csv_delimiter=';'; INSERT INTO csv FORMAT CSV";


$DATASTORE_CLIENT --query="SELECT * FROM csv";

$DATASTORE_CLIENT --query="DROP TABLE csv";
$DATASTORE_CLIENT --query="CREATE TABLE csv (s1 String, s2 String) ENGINE = Memory";

echo '"s1";"s2"
abc,def;hello;
hello; world;
"hello ""world""";abc,def;' | $DATASTORE_CLIENT --query="SET format_csv_delimiter=';'; INSERT INTO csv FORMAT CSVWithNames";

$DATASTORE_CLIENT --format_csv_delimiter=";" --query="SELECT * FROM csv FORMAT CSV";
$DATASTORE_CLIENT --format_csv_delimiter="," --query="SELECT * FROM csv FORMAT CSV";
$DATASTORE_CLIENT --format_csv_delimiter="/" --query="SELECT * FROM csv FORMAT CSV";

$DATASTORE_CLIENT --query="DROP TABLE csv";
