#!/usr/bin/env bash
# Tags: no-fasttest

set -e

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS contributors"
${DATASTORE_CLIENT} --query="CREATE TABLE contributors (name String) ENGINE = Memory"
${DATASTORE_CLIENT} --query="SELECT * FROM system.contributors ORDER BY name DESC FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO contributors FORMAT Arrow"
# random results
${DATASTORE_CLIENT} --query="SELECT * FROM contributors LIMIT 10" > /dev/null
${DATASTORE_CLIENT} --query="DROP TABLE contributors"

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_numbers"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_numbers (number UInt64) ENGINE = Memory"
# less than default block size (65k)
${DATASTORE_CLIENT} --query="SELECT * FROM system.numbers LIMIT 10000 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_numbers FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_numbers ORDER BY number DESC LIMIT 10"
${DATASTORE_CLIENT} --query="TRUNCATE TABLE arrow_numbers"

# More than default block size
${DATASTORE_CLIENT} --query="SELECT * FROM system.numbers LIMIT 100000 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_numbers FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_numbers ORDER BY number DESC LIMIT 10"
${DATASTORE_CLIENT} --query="TRUNCATE TABLE arrow_numbers"

${DATASTORE_CLIENT} --max_block_size=2 --query="SELECT * FROM system.numbers LIMIT 3 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_numbers FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_numbers ORDER BY number DESC LIMIT 10"

${DATASTORE_CLIENT} --query="TRUNCATE TABLE arrow_numbers"
${DATASTORE_CLIENT} --max_block_size=1 --query="SELECT * FROM system.numbers LIMIT 1000 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_numbers FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_numbers ORDER BY number DESC LIMIT 10"

${DATASTORE_CLIENT} --query="DROP TABLE arrow_numbers"

${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_types1"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_types2"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_types3"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_types4"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_types1       (int8 Int8, uint8 UInt8, int16 Int16, uint16 UInt16, int32 Int32, uint32 UInt32, int64 Int64, uint64 UInt64, float32 Float32, float64 Float64, string String, fixedstring FixedString(15), date Date, datetime DateTime, datetime64 DateTime64(6)) ENGINE = Memory"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_types2       (int8 Int8, uint8 UInt8, int16 Int16, uint16 UInt16, int32 Int32, uint32 UInt32, int64 Int64, uint64 UInt64, float32 Float32, float64 Float64, string String, fixedstring FixedString(15), date Date, datetime DateTime, datetime64 DateTime64(6)) ENGINE = Memory"
# convert min type
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_types3       (int8 Int8,  uint8 Int8,  int16 Int8,   uint16 Int8,  int32 Int8,   uint32 Int8,  int64 Int8,   uint64 Int8,    float32 Int8,    float64 Int8, string FixedString(15), fixedstring FixedString(15), date Date,    datetime Date, datetime64 DateTime64(6)) ENGINE = Memory"
# convert max type
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_types4       (int8 Int64, uint8 Int64, int16 Int64, uint16 Int64, int32 Int64,  uint32 Int64, int64 Int64,  uint64 Int64,   float32 Int64,   float64 Int64, string String,          fixedstring String, date DateTime, datetime DateTime, datetime64 DateTime64(6)) ENGINE = Memory"

${DATASTORE_CLIENT} --query="INSERT INTO arrow_types1 values (     -108,         108,       -1016,          1116,       -1032,          1132,       -1064,          1164,          -1.032,          -1.064,    'string-0',               'fixedstring', '2001-02-03', '2002-02-03 04:05:06', toDateTime64('2002-02-03 04:05:06.789012', 6))"

# min
${DATASTORE_CLIENT} --query="INSERT INTO arrow_types1 values (     -128,           0,      -32768,             0, -2147483648,             0, -9223372036854775808, 0,             -1.032,          -1.064,    'string-1',             'fixedstring-1', '2003-04-05', '2003-02-03 04:05:06', toDateTime64('2003-02-03 04:05:06.789012', 6))"

# max
${DATASTORE_CLIENT} --query="INSERT INTO arrow_types1 values (      127,         255,       32767,         65535,  2147483647,    4294967295, 9223372036854775807, 9223372036854775807, -1.032,     -1.064,    'string-2',             'fixedstring-2', '2004-06-07', '2004-02-03 04:05:06', toDateTime64('2004-02-03 04:05:06.789012', 6))"

${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types1 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types2 FORMAT Arrow"

echo original:
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types1 ORDER BY int8" | tee "${DATASTORE_TMP}"/arrow_all_types_1.dump
echo converted:
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types2 ORDER BY int8" | tee "${DATASTORE_TMP}"/arrow_all_types_2.dump
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types1 ORDER BY int8 FORMAT Arrow" > "${DATASTORE_TMP}"/arrow_all_types_1.arrow
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types2 ORDER BY int8 FORMAT Arrow" > "${DATASTORE_TMP}"/arrow_all_types_2.arrow
echo diff:
diff "${DATASTORE_TMP}"/arrow_all_types_1.dump "${DATASTORE_TMP}"/arrow_all_types_2.dump

${DATASTORE_CLIENT} --query="TRUNCATE TABLE arrow_types2"
${DATASTORE_CLIENT} --query="INSERT INTO arrow_types3 values (       79,          81,          82,            83,          84,            85,          86,            87,              88,              89,         'str01',                  'fstr1', '2003-03-04', '2004-05-06', toDateTime64('2005-02-03 04:05:06.789012', 6))"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types3 ORDER BY int8 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types2 FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types1 ORDER BY int8 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types3 FORMAT Arrow"

${DATASTORE_CLIENT} --query="INSERT INTO arrow_types4 values (       80,          81,          82,            83,          84,            85,          86,            87,              88,              89,         'str02',                  'fstr2', '2005-03-04 05:06:07', '2006-08-09 10:11:12', toDateTime64('2007-02-03 04:05:06.789012', 6))"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types4 ORDER BY int8 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types2 FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types1 ORDER BY int8 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types4 FORMAT Arrow"

echo dest:
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types2 ORDER BY int8"
echo min:
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types3 ORDER BY int8"
echo max:
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types4 ORDER BY int8"


${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_types5"
${DATASTORE_CLIENT} --query="DROP TABLE IF EXISTS arrow_types6"
${DATASTORE_CLIENT} --query="TRUNCATE TABLE arrow_types2"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_types5       (int8 Nullable(Int8), uint8 Nullable(UInt8), int16 Nullable(Int16), uint16 Nullable(UInt16), int32 Nullable(Int32), uint32 Nullable(UInt32), int64 Nullable(Int64), uint64 Nullable(UInt64), float32 Nullable(Float32), float64 Nullable(Float64), string Nullable(String), fixedstring Nullable(FixedString(15)), date Nullable(Date), datetime Nullable(DateTime), datetime64 Nullable(DateTime64)) ENGINE = Memory"
${DATASTORE_CLIENT} --query="CREATE TABLE arrow_types6       (int8 Nullable(Int8), uint8 Nullable(UInt8), int16 Nullable(Int16), uint16 Nullable(UInt16), int32 Nullable(Int32), uint32 Nullable(UInt32), int64 Nullable(Int64), uint64 Nullable(UInt64), float32 Nullable(Float32), float64 Nullable(Float64), string Nullable(String), fixedstring Nullable(FixedString(15)), date Nullable(Date), datetime Nullable(DateTime), datetime64 Nullable(DateTime64)) ENGINE = Memory"
${DATASTORE_CLIENT} --query="INSERT INTO arrow_types5 values (               NULL,                  NULL,                  NULL,                    NULL,                  NULL,                    NULL,                  NULL,                    NULL,                      NULL,                      NULL,                    NULL,                                  NULL,                NULL,                        NULL, NULL)"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types5 ORDER BY int8 FORMAT Arrow" > "${DATASTORE_TMP}"/arrow_all_types_5.arrow
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types5 ORDER BY int8 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types6 FORMAT Arrow"
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types1 ORDER BY int8 FORMAT Arrow" | ${DATASTORE_CLIENT} --query="INSERT INTO arrow_types6 FORMAT Arrow"
echo dest from null:
${DATASTORE_CLIENT} --query="SELECT * FROM arrow_types6 ORDER BY int8"

${DATASTORE_CLIENT} --query="DROP TABLE arrow_types5"
${DATASTORE_CLIENT} --query="DROP TABLE arrow_types6"


${DATASTORE_CLIENT} --query="DROP TABLE arrow_types1"
${DATASTORE_CLIENT} --query="DROP TABLE arrow_types2"
${DATASTORE_CLIENT} --query="DROP TABLE arrow_types3"
${DATASTORE_CLIENT} --query="DROP TABLE arrow_types4"

