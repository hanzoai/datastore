#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

path="/test-keeper-client-$DATASTORE_DATABASE"

$DATASTORE_KEEPER_CLIENT -q "rm '$path'" >& /dev/null

# Tree structure:
# /path
# ├── 1
# │   ├── a      (3 children: x, y, z) - super node
# │   │   ├── x  (3 children: p, q, r) - nested super node
# │   │   │   ├── p
# │   │   │   ├── q
# │   │   │   └── r
# │   │   ├── y
# │   │   └── z
# │   └── b
# └── 2          (4 children: a, b, c, d) - super node
#     ├── a
#     ├── b
#     ├── c
#     └── d
$DATASTORE_KEEPER_CLIENT -q "create '$path' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a/x' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a/x/p' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a/x/q' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a/x/r' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a/y' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/a/z' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/1/b' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/2' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/2/a' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/2/b' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/2/c' 'foobar'"
$DATASTORE_KEEPER_CLIENT -q "create '$path/2/d' 'foobar'"

echo 'find_super_nodes'
$DATASTORE_KEEPER_CLIENT -q "find_super_nodes 1000000000"
$DATASTORE_KEEPER_CLIENT -q "find_super_nodes 3 '$path'" | sort

echo 'find_big_family'
$DATASTORE_KEEPER_CLIENT -q "find_big_family '$path' 3"

$DATASTORE_KEEPER_CLIENT -q "rmr '$path'"
