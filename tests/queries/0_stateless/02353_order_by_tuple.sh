#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

[ ! -z "$DATASTORE_CLIENT_REDEFINED" ] && DATASTORE_CLIENT=$DATASTORE_CLIENT_REDEFINED

##################
# check that both queries have the same AST after rewrite, EXPLAIN SYNTAX returns it in form of query
##################
QUERY_ORDER_BY="SELECT number AS a, number % 2 AS b FROM numbers(10) ORDER BY a DESC NULLS FIRST WITH FILL FROM 2 TO 1 STEP -1, b DESC NULLS FIRST WITH FILL FROM 2 TO 1 STEP -1"
QUERY_ORDER_BY_TUPLE="SELECT number AS a, number % 2 AS b FROM numbers(10) ORDER BY (a, b) DESC NULLS FIRST WITH FILL FROM 2 TO 1 STEP -1"

EXPLAIN="EXPLAIN SYNTAX"
OUTPUT_EXPLAIN_ORDER_BY=$($DATASTORE_CLIENT -q "$EXPLAIN $QUERY_ORDER_BY SETTINGS enable_analyzer=0")
echo $OUTPUT_EXPLAIN_ORDER_BY
OUTPUT_EXPLAIN_ORDER_BY_TUPLE=$($DATASTORE_CLIENT -q "$EXPLAIN $QUERY_ORDER_BY_TUPLE SETTINGS enable_analyzer=0")
echo $OUTPUT_EXPLAIN_ORDER_BY_TUPLE

[ "$OUTPUT_EXPLAIN_ORDER_BY" == "$OUTPUT_EXPLAIN_ORDER_BY_TUPLE" ] && echo "OK"
