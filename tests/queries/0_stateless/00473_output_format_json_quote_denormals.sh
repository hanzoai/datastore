#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="select 1/0, -1/0, sqrt(-1), -sqrt(-1) format JSON" --output_format_json_quote_denormals=0 | grep -o null
$DATASTORE_CLIENT --query="select 1/0, -1/0, sqrt(-1), -sqrt(-1) format JSONCompact" --output_format_json_quote_denormals=0 | grep -o null
$DATASTORE_CLIENT --query="select 1/0, -1/0, sqrt(-1), -sqrt(-1) format JSONEachRow" --output_format_json_quote_denormals=0 | grep -o null

$DATASTORE_CLIENT --query="select 1/0, -1/0, sqrt(-1), -sqrt(-1) format JSON" --output_format_json_quote_denormals=1 | grep -o "inf\|-inf\|nan"
$DATASTORE_CLIENT --query="select 1/0, -1/0, sqrt(-1), -sqrt(-1) format JSONCompact" --output_format_json_quote_denormals=1 | grep -o "inf\|-inf\|nan"
$DATASTORE_CLIENT --query="select 1/0, -1/0, sqrt(-1), -sqrt(-1) format JSONEachRow" --output_format_json_quote_denormals=1 | grep -o "inf\|-inf\|nan"
