#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

$DATASTORE_LOCAL -q "desc format(JSONEachRow, '{\"x\" : 1.2}')";
echo '{"x" : 1.2}' | $DATASTORE_LOCAL --input-format='JSONEachRow' --table='test' -q "desc test";
$DATASTORE_LOCAL -q "desc format(JSONEachRow, '{\"x\" : 1}')";
echo '{"x" : 1}' | $DATASTORE_LOCAL --input-format='JSONEachRow' --table='test' -q "desc test";
$DATASTORE_LOCAL -q "desc format(JSONEachRow, '{\"x\" : 1e10}')" --input_format_try_infer_exponent_floats=1;
echo '{"x" : 1e10}' | $DATASTORE_LOCAL --input-format='JSONEachRow' --table='test' -q "desc test" --input_format_try_infer_exponent_floats=1;
$DATASTORE_LOCAL -q "desc format(JSONEachRow, '{\"x\" : [1, 42.42, 1, 1e10]}')" --input_format_try_infer_exponent_floats=1;
echo '{"x" : [1, 42.42, 1, 1e10]}' | $DATASTORE_LOCAL --input-format='JSONEachRow' --table='test' -q "desc test" --input_format_try_infer_exponent_floats=1;
$DATASTORE_LOCAL -q "desc format(JSONEachRow, '{\"x\" : [1, 42.42, false]}')";
echo '{"x" : [1, 42.42, false]}' | $DATASTORE_LOCAL --input-format='JSONEachRow' --table='test' -q "desc test";

$DATASTORE_LOCAL -q "desc format(TSV, '1.2')";
echo '1.2' | $DATASTORE_LOCAL --input-format='TSV' --table='test' -q "desc test";
$DATASTORE_LOCAL -q "desc format(TSV, '1')";
echo '1' | $DATASTORE_LOCAL --input-format='TSV' --table='test' -q "desc test";
$DATASTORE_LOCAL -q "desc format(TSV, '1e10')" --input_format_try_infer_exponent_floats=1;
echo '1e10' | $DATASTORE_LOCAL --input-format='TSV' --table='test' -q "desc test" --input_format_try_infer_exponent_floats=1;
$DATASTORE_LOCAL -q "desc format(TSV, '[1, 42.42, 1, 1e10]')" --input_format_try_infer_exponent_floats=1;
echo '[1, 42.42, 1, 1e10]' | $DATASTORE_LOCAL --input-format='TSV' --table='test' -q "desc test" --input_format_try_infer_exponent_floats=1;
$DATASTORE_LOCAL -q "desc format(TSV, '[1, 42.42, false]')";
echo '[1, 42.42, false]' | $DATASTORE_LOCAL --input-format='TSV' --table='test' -q "desc test";

