#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

http_url="http://${DATASTORE_HOST}:${DATASTORE_PORT_HTTP}/?"

curl -s "${http_url}temp_structure=x+Enum8('foo'%3D1,'bar'%3D2),y+Int" -F "$(printf 'temp='"foo"'\t1');filename=data1" -F "query=SELECT * FROM temp"
curl -s "${http_url}temp_types=Enum8('foo'%3D1,'bar'%3D2),Int" -F "$(printf 'temp='"bar"'\t2');filename=data1" -F "query=SELECT * FROM temp"
echo -ne 'foo\t1' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --structure="x Enum8('foo'=1,'bar'=2),y Int"
echo -ne 'bar\t2' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --types="Enum8('foo'=1,'bar'=2),Int"

# https://github.com/ClickHouse/Datastore/issues/62108
echo -ne 'true' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --structure="x Bool"
echo -ne 'true' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --types="Bool"

# Test for some complex and custome types
echo -ne 'true' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --structure="x Nullable(FixedString(4))"
echo -ne '[1]' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --structure="x Array(UInt8)"
echo -ne '('"'"'foo'"'"',1)' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --structure="x Tuple(String, UInt8)"
echo -ne '(1,1)' | ${DATASTORE_CLIENT} --query="select * from tmp" --external --file=- --name=tmp --structure="x Point"
