#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_str.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_unicode.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim_float.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim_str.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim_unicode.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim_bool.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim_null.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/three_dim.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/none_endian_array.npy')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/big_endian_array.npy')"

$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/one_dim.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/one_dim_float.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/one_dim_str.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/one_dim_unicode.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/two_dim.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/two_dim_float.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/two_dim_str.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/two_dim_unicode.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/two_dim_bool.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/two_dim_null.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/three_dim.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/none_endian_array.npy')"
$DATASTORE_LOCAL -q "describe file('$CURDIR/data_npy/big_endian_array.npy')"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value UInt8')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value UInt16')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value UInt32')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value UInt64')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value Int8')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value Int16')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value Int32')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim.npy', Npy, 'value Int64')"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy', Npy, 'value Float32')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy', Npy, 'value Float64')"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_str.npy', Npy, 'value FixedString(1)')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_str.npy', Npy, 'value String')"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/two_dim.npy', Npy, 'value Array(Int8)')"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/three_dim.npy', Npy, 'value Array(Array(Int8))')"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy', Npy, 'value Array(Float32)')" 2>&1 | grep -c "BAD_ARGUMENTS"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy', Npy, 'value UUID')" 2>&1 | grep -c "UNKNOWN_TYPE"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy', Npy, 'value Tuple(UInt8)')" 2>&1 | grep -c "UNKNOWN_TYPE"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_float.npy', Npy, 'value Int8')" 2>&1 | grep -c "ILLEGAL_COLUMN"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_str.npy', Npy, 'value Int8')" 2>&1 | grep -c "ILLEGAL_COLUMN"
$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/one_dim_unicode.npy', Npy, 'value Float32')" 2>&1 | grep -c "ILLEGAL_COLUMN"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/complex.npy')" 2>&1 | grep -c "CANNOT_EXTRACT_TABLE_STRUCTURE"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/float_16.npy')"

$DATASTORE_LOCAL -q "select * from file('$CURDIR/data_npy/npy_inf_nan_null.npy')"
