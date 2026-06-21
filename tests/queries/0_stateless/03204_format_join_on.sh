#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# regression for the JOIN ON alias for the whole expression
phase1="$($DATASTORE_FORMAT --oneline --query "SELECT * FROM t1 JOIN t2 ON ((t1.x = t2.x) AND (t1.x IS NULL) AS e2)")"
echo "$phase1"
# phase 2
$DATASTORE_FORMAT --oneline --query "$phase1"

# other test cases
$DATASTORE_FORMAT --oneline --query "SELECT * FROM t1 JOIN t2 ON (t1.x = t2.x) AND (t1.x IS NULL AS e2)"
$DATASTORE_FORMAT --oneline --query "SELECT * FROM t1 JOIN t2 ON t1.x = t2.x"
