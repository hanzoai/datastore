#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

# Test that datastore help returns 0
$DATASTORE_BINARY help >/dev/null 2>&1
echo "datastore help: $?"

# Test that datastore --help returns 0 (dispatcher help)
$DATASTORE_BINARY --help >/dev/null 2>&1
echo "datastore --help: $?"

# Test that datastore -h (alone) returns 0 (dispatcher help)
$DATASTORE_BINARY -h >/dev/null 2>&1
echo "datastore -h: $?"

# Test that datastore -? returns 0 (dispatcher help)
$DATASTORE_BINARY -? >/dev/null 2>&1
echo "datastore -?: $?"

# Test that datastore start --help returns 0
$DATASTORE_BINARY start --help >/dev/null 2>&1
echo "datastore start --help: $?"

# Test that datastore stop --help returns 0
$DATASTORE_BINARY stop --help >/dev/null 2>&1
echo "datastore stop --help: $?"

# Test that datastore status --help returns 0
$DATASTORE_BINARY status --help >/dev/null 2>&1
echo "datastore status --help: $?"

# Test that datastore restart --help returns 0
$DATASTORE_BINARY restart --help >/dev/null 2>&1
echo "datastore restart --help: $?"

# Test that datastore install --help returns 0
$DATASTORE_BINARY install --help >/dev/null 2>&1
echo "datastore install --help: $?"

# Test that datastore format --help returns 0
$DATASTORE_BINARY format --help >/dev/null 2>&1
echo "datastore format --help: $?"

# Test that datastore extract-from-config --help returns 0
$DATASTORE_BINARY extract-from-config --help >/dev/null 2>&1
echo "datastore extract-from-config --help: $?"

# Test that datastore git-import --help returns 0
$DATASTORE_BINARY git-import --help >/dev/null 2>&1
echo "datastore git-import --help: $?"

# Test that datastore hash-binary --help returns 0
$DATASTORE_BINARY hash-binary --help >/dev/null 2>&1
echo "datastore hash-binary --help: $?"

# Test that datastore benchmark --help returns 0
$DATASTORE_BINARY benchmark --help >/dev/null 2>&1
echo "datastore benchmark --help: $?"

# Test that datastore compressor --help returns 0
$DATASTORE_BINARY compressor --help >/dev/null 2>&1
echo "datastore compressor --help: $?"

# Test that datastore obfuscator --help returns 0
$DATASTORE_BINARY obfuscator --help >/dev/null 2>&1
echo "datastore obfuscator --help: $?"

# Test that datastore server --help returns 0
$DATASTORE_BINARY server --help >/dev/null 2>&1
echo "datastore server --help: $?"

# Test that datastore keeper --help returns 0 (keeper is optional)
if $DATASTORE_BINARY help 2>&1 | grep -qF 'datastore keeper [args]'; then
    $DATASTORE_BINARY keeper --help >/dev/null 2>&1
    echo "datastore keeper --help: $?"
else
    echo "datastore keeper --help: 0"
fi

# Test that datastore client --help returns 0
$DATASTORE_BINARY client --help >/dev/null 2>&1
echo "datastore client --help: $?"

# Test that datastore local --help returns 0
$DATASTORE_BINARY local --help >/dev/null 2>&1
echo "datastore local --help: $?"
