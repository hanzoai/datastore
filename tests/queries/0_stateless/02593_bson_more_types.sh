#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$DATASTORE_LOCAL -q "select map('a\0b', 42) as c1 format BSONEachRow" | $DATASTORE_LOCAL --input-format BSONEachRow --table test --structure "c1 Map(String, UInt32)" -q "select * from test"

$DATASTORE_LOCAL -q "select 'a'::Enum8('a' = 1) as c1, 'b'::Enum16('b' = 1) as c2, map(42, 42) as c3 format BSONEachRow" | $DATASTORE_LOCAL --input-format BSONEachRow --table test -q "desc test"

$DATASTORE_LOCAL -q "select 'a'::Enum8('a' = 1) as c1, 'b'::Enum16('b' = 1) as c2, map(42, 42) as c3 format BSONEachRow" | $DATASTORE_LOCAL --input-format BSONEachRow --table test --structure "c1 Enum8('a' = 1), c2 Enum16('b' = 1), c3 Map(UInt32, UInt32)" -q "select * from test"


