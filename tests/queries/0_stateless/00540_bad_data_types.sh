#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_CLIENT --query="SELECT CAST(0 AS Array)" 2>/dev/null || true;
$DATASTORE_CLIENT --query="SELECT CAST(0 AS AggregateFunction)" 2>/dev/null || true;
$DATASTORE_CLIENT --query="SELECT CAST(0 AS Nullable)" 2>/dev/null || true;
$DATASTORE_CLIENT --query="SELECT CAST(0 AS Tuple)" 2>/dev/null || true;
$DATASTORE_CLIENT --query="SELECT CAST(0 AS FixedString)" 2>/dev/null || true;
$DATASTORE_CLIENT --query="SELECT CAST(0 AS Enum)" 2>/dev/null || true;
$DATASTORE_CLIENT --query="SELECT CAST(0 AS DateTime('UTC'))";

echo

($DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE toString(dummy)" 2>/dev/null && echo "Expected failure") || true;
($DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE toString(1)" 2>/dev/null && echo "Expected failure") || true;
($DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE 0.1::BFloat16" 2>/dev/null && echo "Expected failure") || true;
($DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE materialize(0.1::BFloat16)" 2>/dev/null && echo "Expected failure") || true;

$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE 256";
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE -1";
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE CAST(256 AS Nullable(UInt16))";
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE CAST(NULL AS Nullable(UInt8))"
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE 255"
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE CAST(255 AS Nullable(UInt8))"
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE 0.1";
$DATASTORE_CLIENT --query="SELECT * FROM system.one WHERE materialize(0.1)";

# We don't filter out inf/nan. This is questionable, but compatible with AND implementation.
$DATASTORE_CLIENT --query="SELECT (1.0 / 0) as x FROM system.one WHERE x";
$DATASTORE_CLIENT --query="SELECT (1.0 / 0) as x FROM system.one WHERE materialize(x)";
$DATASTORE_CLIENT --query="SELECT (1.0 / 0) as x FROM system.one WHERE 1 and x";
$DATASTORE_CLIENT --query="SELECT (1.0 / 0) as x FROM system.one WHERE 1 and materialize(x)";

$DATASTORE_CLIENT --query="SELECT (0.0 / 0) as x FROM system.one WHERE x";
$DATASTORE_CLIENT --query="SELECT (0.0 / 0) as x FROM system.one WHERE materialize(x)";
$DATASTORE_CLIENT --query="SELECT (0.0 / 0) as x FROM system.one WHERE 1 and x";
$DATASTORE_CLIENT --query="SELECT (0.0 / 0) as x FROM system.one WHERE 1 and materialize(x)";
