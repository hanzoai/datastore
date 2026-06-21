#!/usr/bin/env bash
# Tags: no-fasttest

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh

if ! command -v gzip &> /dev/null; then echo "gzip not found" 1>&2; exit 1; fi
if ! command -v brotli &> /dev/null; then echo "brotli not found" 1>&2; exit 1; fi
if ! command -v xz &> /dev/null; then echo "xz not found" 1>&2; exit 1; fi
if ! command -v zstd &> /dev/null; then echo "zstd not found" 1>&2; exit 1; fi

${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1"                                     -d 'SELECT number FROM system.numbers LIMIT 10';
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=0" -H 'Accept-Encoding: gzip'          -d 'SELECT number FROM system.numbers LIMIT 10';
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: gzip'          -d 'SELECT number FROM system.numbers LIMIT 10' | gzip -d;
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: gzip, deflate' -d 'SELECT number FROM system.numbers LIMIT 10' | gzip -d;
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: zip, eflate'   -d 'SELECT number FROM system.numbers LIMIT 10';
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: br'            -d 'SELECT number FROM system.numbers LIMIT 10' | brotli -d;
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: xz'            -d 'SELECT number FROM system.numbers LIMIT 10' | xz -d;
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: zstd'          -d 'SELECT number FROM system.numbers LIMIT 10' | zstd -d;
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: lz4'           -d 'SELECT number FROM system.numbers LIMIT 10' | lz4 -d;
${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: bz2'           -d 'SELECT number FROM system.numbers LIMIT 10' | bzip2 -d;

${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1"                                     -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: gzip'          -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: deflate'       -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: gzip, deflate' -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: zip, eflate'   -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: br'            -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: xz'            -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: zstd'          -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: lz4'           -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: bz2'           -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';
${DATASTORE_CURL} -vsS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: snappy'        -d 'SELECT number FROM system.numbers LIMIT 10' 2>&1 | grep --text '< Content-Encoding';

echo "SELECT 1" | ${DATASTORE_CURL} -sS --data-binary @- "${DATASTORE_URL}";
echo "SELECT 1" | gzip -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: gzip' "${DATASTORE_URL}";
echo "SELECT 1" | brotli | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: br' "${DATASTORE_URL}";
echo "SELECT 1" | xz -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: xz' "${DATASTORE_URL}";
echo "SELECT 1" | zstd -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: zstd' "${DATASTORE_URL}";
echo "SELECT 1" | lz4 -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: lz4' "${DATASTORE_URL}";
echo "SELECT 1" | bzip2 -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: bz2' "${DATASTORE_URL}";

echo "'Hello, world'" | ${DATASTORE_CURL} -sS --data-binary @- "${DATASTORE_URL}&query=SELECT";
echo "'Hello, world'" | gzip -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: gzip' "${DATASTORE_URL}&query=SELECT";
echo "'Hello, world'" | brotli | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: br' "${DATASTORE_URL}&query=SELECT";
echo "'Hello, world'" | xz -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: xz' "${DATASTORE_URL}&query=SELECT";
echo "'Hello, world'" | zstd -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: zstd' "${DATASTORE_URL}&query=SELECT";
echo "'Hello, world'" | lz4 -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: lz4' "${DATASTORE_URL}&query=SELECT";
echo "'Hello, world'" | bzip2 -c | ${DATASTORE_CURL} -sS --data-binary @- -H 'Content-Encoding: bz2' "${DATASTORE_URL}&query=SELECT";

${DATASTORE_CURL} -sS "${DATASTORE_URL}&enable_http_compression=1" -H 'Accept-Encoding: gzip'          -d 'SELECT number FROM system.numbers LIMIT 0' | wc -c;

# POST multiple concatenated gzip and bzip2 streams.
(echo -n "SELECT 'Part1" | gzip -c; echo " Part2'" | gzip -c) | ${DATASTORE_CURL} -sS -H 'Content-Encoding: gzip' "${DATASTORE_URL}" --data-binary @-
(echo -n "SELECT 'Part1" | bzip2 -c; echo " Part2'" | bzip2 -c) | ${DATASTORE_CURL} -sS -H 'Content-Encoding: bz2' "${DATASTORE_URL}" --data-binary @-
