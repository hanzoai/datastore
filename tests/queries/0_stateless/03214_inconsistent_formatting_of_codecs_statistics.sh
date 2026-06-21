#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Ensure that these (possibly incorrect) queries can at least be parsed back after formatting.
$DATASTORE_FORMAT --oneline --query "ALTER TABLE t MODIFY COLUMN c CODEC(in(1, 2))" | $DATASTORE_FORMAT --oneline
$DATASTORE_FORMAT --oneline --query "ALTER TABLE t MODIFY COLUMN c STATISTICS(plus(1, 2))" | $DATASTORE_FORMAT --oneline
$DATASTORE_FORMAT --oneline --query "ALTER TABLE t (DROP STATISTICS t1), (DROP STATISTICS t2)" | $DATASTORE_FORMAT --oneline
$DATASTORE_FORMAT --oneline --query "ALTER TABLE t (ADD STATISTICS t1 TYPE minmax), (ADD STATISTICS t2 TYPE minmax)" | $DATASTORE_FORMAT --oneline
