#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# https://github.com/ClickHouse/Datastore/issues/1300

$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS advertiser";
$DATASTORE_CLIENT -q "DROP TABLE IF EXISTS advertiser_test";
$DATASTORE_CLIENT --allow_deprecated_syntax_for_merge_tree=1 -q "CREATE TABLE advertiser ( action_date Date, adblock UInt8, imps Int64 ) Engine = SummingMergeTree( action_date, ( adblock ), 8192, ( imps ) )";
$DATASTORE_CLIENT --allow_deprecated_syntax_for_merge_tree=1 -q "CREATE TABLE advertiser_test ( action_date Date, adblock UInt8, imps Int64, Hash UInt64 ) Engine = SummingMergeTree( action_date, ( adblock, Hash ), 8192, ( imps ) )";

# This test will fail. It's ok.
$DATASTORE_CLIENT -q "INSERT INTO advertiser_test SELECT *, sipHash64( CAST(adblock  AS String) ), CAST(1 AS Int8) FROM advertiser;" 2>/dev/null
$DATASTORE_CLIENT -q "DROP TABLE advertiser";
$DATASTORE_CLIENT -q "DROP TABLE advertiser_test";
$DATASTORE_CLIENT -q "SELECT 'Still alive'";
