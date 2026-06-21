#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

filename="${DATASTORE_TEST_UNIQUE_NAME}"_02566_ipv4_ipv6
echo "CapnProto"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format CapnProto settings format_schema='$CURDIR/format_schemas/02566_ipv4_ipv6:Message'" > $filename.capnp
${DATASTORE_LOCAL} -q "select * from file($filename.capnp, auto, 'ipv6 IPv6, ipv4 IPv4') settings format_schema='$CURDIR/format_schemas/02566_ipv4_ipv6:Message'"
rm $filename.capnp

echo "Avro"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format Avro"  > $filename.avro
${DATASTORE_LOCAL} -q "select * from file($filename.avro, auto, 'ipv6 IPv6, ipv4 IPv4')"
rm $filename.avro

echo "Arrow"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format Arrow"  > $filename.arrow
${DATASTORE_LOCAL} -q "select * from file($filename.arrow, auto, 'ipv6 IPv6, ipv4 IPv4')"
rm $filename.arrow

echo "Parquet"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format Parquet"  > $filename.parquet
${DATASTORE_LOCAL} -q "desc file($filename.parquet)"
${DATASTORE_LOCAL} -q "select ipv6, toIPv4(ipv4) from file($filename.parquet, auto, 'ipv6 IPv6, ipv4 UInt32')"
rm $filename.parquet

echo "ORC"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format ORC"  > $filename.orc
${DATASTORE_LOCAL} -q "desc file($filename.orc)"
${DATASTORE_LOCAL} -q "select ipv6, toIPv4(ipv4) from file($filename.orc, auto, 'ipv6 IPv6, ipv4 UInt32')"
rm $filename.orc

echo "BSONEachRow"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format BSONEachRow"  > $filename.bson
${DATASTORE_LOCAL} -q "select * from file($filename.bson, auto, 'ipv6 IPv6, ipv4 IPv4')"
rm $filename.bson

echo "MsgPack"
${DATASTORE_LOCAL} -q "select '2001:db8:11a3:9d7:1f34:8a2e:7a0:765d'::IPv6 as ipv6, '127.0.0.1'::IPv4 as ipv4 format MsgPack"  > $filename.msgpack
${DATASTORE_LOCAL} -q "select * from file($filename.msgpack, auto, 'ipv6 IPv6, ipv4 IPv4')"
rm $filename.msgpack


