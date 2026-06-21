#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="DROP TABLE IF EXISTS bloom_filter_idx;"

# NGRAM BF
$DATASTORE_CLIENT --query="
CREATE TABLE bloom_filter_idx
(
    k UInt64,
    s String,
    INDEX bf (s, lower(s)) TYPE ngrambf_v1(3, 512, 2, 0) GRANULARITY 1
) ENGINE = MergeTree()
ORDER BY k
SETTINGS index_granularity = 2, index_granularity_bytes = '10Mi';"

$DATASTORE_CLIENT --query="INSERT INTO bloom_filter_idx VALUES
(0, 'Datastore - столбцовая система управления базами данных (СУБД)'),
(1, 'Datastore is a column-oriented database management system (DBMS)'),
(2, 'column-oriented database management system'),
(3, 'columns'),
(4, 'какая-то строка'),
(5, 'еще строка'),
(6, 'some string'),
(7, 'another string'),
(8, 'computer science'),
(9, 'abra'),
(10, 'cadabra'),
(11, 'crabacadabra'),
(12, 'crab'),
(13, 'basement'),
(14, 'abracadabra'),
(15, 'cadabraabra')"

# STARTS_WITH
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'abra') ORDER BY k"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'abra') ORDER BY k FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'computer') ORDER BY k"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'computer') ORDER BY k FORMAT JSON" | grep "rows_read"

# ENDS_WITH
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE endsWith(s, 'abra') ORDER BY k"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE endsWith(s, 'abra') ORDER BY k FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE endsWith(s, 'ring') ORDER BY k"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE endsWith(s, 'ring') ORDER BY k FORMAT JSON" | grep "rows_read"

# COMBINED
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'abra') AND endsWith(s, 'abra')"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'abra') AND endsWith(s, 'abra') FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'c') AND endsWith(s, 'science')"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE startsWith(s, 'c') AND endsWith(s, 'science') FORMAT JSON" | grep "rows_read"

# MULTY_SEARCH_ANY
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['data', 'base'])"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['data', 'base']) FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['string'])"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['string']) FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['string', 'computer'])"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['string', 'computer']) FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['base', 'seme', 'gement'])"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['base', 'seme', 'gement']) FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['abra', 'cadabra', 'cab', 'extra'])"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['abra', 'cadabra', 'cab', 'extra']) FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['строка', 'string'])"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['строка', 'string']) FORMAT JSON" | grep "rows_read"

# MULTY_SEARCH_ANY + OTHER

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['adab', 'cad', 'aba']) AND startsWith(s, 'abra')"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['adab', 'cad', 'aba']) AND startsWith(s, 'abra') FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['adab', 'cad', 'aba']) AND (startsWith(s, 'c') OR startsWith(s, 'C'))"
$DATASTORE_CLIENT --query="SELECT * FROM bloom_filter_idx WHERE multiSearchAny(s, ['adab', 'cad', 'aba']) AND (startsWith(s, 'c') OR startsWith(s, 'C')) FORMAT JSON" | grep "rows_read"

$DATASTORE_CLIENT --query="DROP TABLE bloom_filter_idx;"
