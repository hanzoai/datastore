#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

echo 'one block'
${DATASTORE_LOCAL} --query="SELECT * FROM numbers(2) SETTINGS output_format_pretty_color=1" --format PrettyCompactMonoBlock
echo 'two blocks'
${DATASTORE_LOCAL} --query="SELECT * FROM numbers(1) UNION ALL SELECT * FROM numbers(1) SETTINGS output_format_pretty_color=1" --format PrettyCompactMonoBlock
echo 'extremes'
${DATASTORE_LOCAL} --query="SELECT * FROM numbers(3) SETTINGS output_format_pretty_color=1" --format PrettyCompactMonoBlock --extremes=1
echo 'totals'
${DATASTORE_LOCAL} --query="SELECT sum(number) FROM numbers(3) GROUP BY number%2 WITH TOTALS ORDER BY number%2 SETTINGS output_format_pretty_color=1" --format PrettyCompactMonoBlock
