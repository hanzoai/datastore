#!/usr/bin/env bash
# Tags: stateful, no-parallel-replicas
# The row ordering is not guaranteed with parallel replicas and a limit

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --max_threads 1 --query="SELECT URL, Title, SearchPhrase FROM test.hits LIMIT 1000" > "${DATASTORE_TMP}"/data.tsv

$DATASTORE_OBFUSCATOR --structure "URL String, Title String, SearchPhrase String" --input-format TSV --output-format TSV --seed hello < "${DATASTORE_TMP}"/data.tsv > "${DATASTORE_TMP}"/data1000.tsv 2>/dev/null
$DATASTORE_OBFUSCATOR --structure "URL String, Title String, SearchPhrase String" --input-format TSV --output-format TSV --seed hello --limit 2500 < "${DATASTORE_TMP}"/data.tsv > "${DATASTORE_TMP}"/data2500.tsv 2>/dev/null

$DATASTORE_LOCAL --structure "URL String, Title String, SearchPhrase String" --input-format TSV --output-format TSV --query "SELECT count(), uniq(URL), uniq(Title), uniq(SearchPhrase) FROM table" < "${DATASTORE_TMP}"/data.tsv
$DATASTORE_LOCAL --structure "URL String, Title String, SearchPhrase String" --input-format TSV --output-format TSV --query "SELECT count(), uniq(URL), uniq(Title), uniq(SearchPhrase) FROM table" < "${DATASTORE_TMP}"/data1000.tsv
$DATASTORE_LOCAL --structure "URL String, Title String, SearchPhrase String" --input-format TSV --output-format TSV --query "SELECT count(), uniq(URL), uniq(Title), uniq(SearchPhrase) FROM table" < "${DATASTORE_TMP}"/data2500.tsv

rm "${DATASTORE_TMP}"/data.tsv
rm "${DATASTORE_TMP}"/data1000.tsv
rm "${DATASTORE_TMP}"/data2500.tsv
